const mongoose = require('mongoose');
const Comment = require('../models/Comment');
const { getNextSequence } = require('../models/Counter');
const { broadcast } = require('../websocket/wsHandler');

// 1. Fetch Root Comments with Cursor Pagination
exports.getRootComments = async (req, res, next) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(200).json({
        comments: [],
        nextCursor: null,
        hasMore: false,
      });
    }

    const limit = parseInt(req.query.limit, 10) || 20;
    const cursor = req.query.cursor; // ISO date string or createdAt timestamp

    const query = { parentId: null };
    if (cursor) {
      query.createdAt = { $lt: new Date(cursor) };
    }

    const comments = await Comment.find(query)
      .sort({ createdAt: -1 })
      .limit(limit + 1);

    const hasMore = comments.length > limit;
    if (hasMore) {
      comments.pop();
    }

    const nextCursor = hasMore && comments.length > 0
      ? comments[comments.length - 1].createdAt.toISOString()
      : null;

    res.status(200).json({
      comments: comments.map((c) => c.toJSON()),
      nextCursor,
      hasMore,
    });
  } catch (error) {
    next(error);
  }
};

// 2. Fetch All Comments (for complete tree loading or replies)
exports.getAllComments = async (req, res, next) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(200).json({
        comments: [],
      });
    }

    const comments = await Comment.find().sort({ createdAt: 1 });
    res.status(200).json({
      comments: comments.map((c) => c.toJSON()),
    });
  } catch (error) {
    next(error);
  }
};

// 3. Create a Comment or Reply
exports.createComment = async (req, res, next) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({ error: 'Database service is offline. Please start MongoDB to post or reply to comments.' });
    }

    const { message, parentId } = req.body;
    const author = {
      id: req.user.id,
      username: req.user.username,
    };

    if (!message || message.trim().length === 0) {
      return res.status(400).json({ error: 'Comment message cannot be empty.' });
    }

    // Validate parent if parentId provided
    if (parentId) {
      const parentComment = await Comment.findById(parentId);
      if (!parentComment) {
        return res.status(404).json({ error: 'Parent comment not found.' });
      }
      if (parentComment.isDeleted) {
        return res.status(400).json({ error: 'Cannot reply to a deleted comment.' });
      }
    }

    const eventId = await getNextSequence('commentEventId');

    const comment = await Comment.create({
      parentId: parentId || null,
      author,
      message: message.trim(),
      eventId,
    });

    const jsonComment = comment.toJSON();

    // Broadcast WebSocket event
    broadcast('NEW_COMMENT', jsonComment);

    res.status(201).json(jsonComment);
  } catch (error) {
    next(error);
  }
};

// 4. Edit a Comment (Authors only, within 5 minutes)
exports.editComment = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { message } = req.body;

    if (!message || message.trim().length === 0) {
      return res.status(400).json({ error: 'Comment message cannot be empty.' });
    }

    const comment = await Comment.findById(id);
    if (!comment) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    if (comment.author.id !== req.user.id) {
      return res.status(403).json({ error: 'You can only edit your own comments.' });
    }

    if (comment.isDeleted) {
      return res.status(400).json({ error: 'Cannot edit a deleted comment.' });
    }

    // Check 5-minute edit window
    const now = Date.now();
    const createdTime = new Date(comment.createdAt).getTime();
    const diffMinutes = (now - createdTime) / (1000 * 60);

    if (diffMinutes > 5) {
      return res.status(400).json({ error: 'Comments can only be edited within 5 minutes of posting.' });
    }

    const eventId = await getNextSequence('commentEventId');

    comment.message = message.trim();
    comment.editedAt = new Date();
    comment.eventId = eventId;
    await comment.save();

    const jsonComment = comment.toJSON();

    // Broadcast live WebSocket edit event
    broadcast('EDIT_COMMENT', jsonComment);

    res.status(200).json(jsonComment);
  } catch (error) {
    next(error);
  }
};

// 5. Soft / Hard Delete a Comment
exports.deleteComment = async (req, res, next) => {
  try {
    const { id } = req.params;

    const comment = await Comment.findById(id);
    if (!comment) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    if (comment.author.id !== req.user.id) {
      return res.status(403).json({ error: 'You can only delete your own comments.' });
    }

    if (comment.isDeleted) {
      return res.status(400).json({ error: 'Comment is already deleted.' });
    }

    // Check if node has children
    const childCount = await Comment.countDocuments({ parentId: id });
    const eventId = await getNextSequence('commentEventId');

    if (childCount > 0) {
      // Has children -> Tombstone (soft delete)
      comment.isDeleted = true;
      comment.message = '[deleted]';
      comment.eventId = eventId;
      await comment.save();

      const jsonComment = comment.toJSON();
      broadcast('DELETE_COMMENT', jsonComment);
      return res.status(200).json(jsonComment);
    } else {
      // Leaf comment -> Hard remove
      comment.isDeleted = true;
      comment.message = '[deleted]';
      comment.eventId = eventId;
      await comment.save();

      const jsonComment = comment.toJSON();
      broadcast('DELETE_COMMENT', jsonComment);
      return res.status(200).json(jsonComment);
    }
  } catch (error) {
    next(error);
  }
};

// 6. Like / Unlike a Comment (Atomic toggle)
exports.toggleLike = async (req, res, next) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res.status(503).json({ error: 'Database service is offline. Please start MongoDB to like comments.' });
    }

    const { id } = req.params;
    const userId = req.user.id;

    const comment = await Comment.findById(id);
    if (!comment) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    if (comment.isDeleted) {
      return res.status(400).json({ error: 'Cannot like a deleted comment.' });
    }

    const likedByList = comment.likedBy || [];
    const hasLiked = likedByList.includes(userId);
    const eventId = await getNextSequence('commentEventId');

    let updatedComment;
    if (hasLiked) {
      // Unlike
      updatedComment = await Comment.findByIdAndUpdate(
        id,
        {
          $pull: { likedBy: userId },
          $inc: { likes: -1 },
          $set: { eventId },
        },
        { new: true }
      );
    } else {
      // Like
      updatedComment = await Comment.findByIdAndUpdate(
        id,
        {
          $addToSet: { likedBy: userId },
          $inc: { likes: 1 },
          $set: { eventId },
        },
        { new: true }
      );
    }

    if (!updatedComment) {
      return res.status(404).json({ error: 'Comment not found.' });
    }

    const jsonComment = updatedComment.toJSON();

    // Broadcast like update live
    broadcast('LIKE_UPDATE', jsonComment);

    res.status(200).json(jsonComment);
  } catch (error) {
    next(error);
  }
};

// 7. Search Comments (Returns matched comments with full parent chain for client auto-expand)
exports.searchComments = async (req, res, next) => {
  try {
    const query = req.query.q;
    if (!query || query.trim().length === 0) {
      return res.status(200).json({ matches: [], ancestorMap: {} });
    }

    const regex = new RegExp(query.trim(), 'i');
    const matches = await Comment.find({
      message: regex,
      isDeleted: false,
    });

    // Build ancestor map for auto-expanding collapsed branches
    const allComments = await Comment.find();
    const commentParentMap = new Map();
    allComments.forEach((c) => commentParentMap.set(c._id, c.parentId));

    const ancestorMap = {}; // matchId -> list of parent ancestor IDs
    matches.forEach((m) => {
      const ancestors = [];
      let currParent = commentParentMap.get(m._id);
      while (currParent) {
        ancestors.push(currParent);
        currParent = commentParentMap.get(currParent);
      }
      ancestorMap[m._id] = ancestors;
    });

    res.status(200).json({
      matches: matches.map((c) => c.toJSON()),
      ancestorMap,
    });
  } catch (error) {
    next(error);
  }
};

// 8. Missed Event Recovery (For reconnecting WebSocket clients)
exports.getMissedEvents = async (req, res, next) => {
  try {
    const sinceEventId = parseInt(req.query.since, 10) || 0;

    const missedEvents = await Comment.find({
      eventId: { $gt: sinceEventId },
    }).sort({ eventId: 1 });

    res.status(200).json({
      events: missedEvents.map((c) => c.toJSON()),
      lastEventId: missedEvents.length > 0 ? missedEvents[missedEvents.length - 1].eventId : sinceEventId,
    });
  } catch (error) {
    next(error);
  }
};
