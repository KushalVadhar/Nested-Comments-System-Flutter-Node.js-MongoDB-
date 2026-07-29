const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');

const commentSchema = new mongoose.Schema(
  {
    _id: {
      type: String,
      default: uuidv4,
    },
    parentId: {
      type: String,
      default: null,
      index: true,
    },
    author: {
      id: { type: String, required: true },
      username: { type: String, required: true },
    },
    message: {
      type: String,
      required: [true, 'Message is required'],
      trim: true,
    },
    likes: {
      type: Number,
      default: 0,
    },
    likedBy: {
      type: [String],
      default: [],
    },
    isDeleted: {
      type: Boolean,
      default: false,
    },
    createdAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    editedAt: {
      type: Date,
      default: null,
    },
    eventId: {
      type: Number,
      unique: true,
      index: true,
    },
  },
  {
    timestamps: false,
  }
);

commentSchema.index({ parentId: 1, createdAt: -1 });

commentSchema.set('toJSON', {
  transform: (doc, ret) => {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    if (ret.createdAt) ret.createdAt = ret.createdAt.toISOString();
    if (ret.editedAt) ret.editedAt = ret.editedAt.toISOString();
    return ret;
  },
});

module.exports = mongoose.model('Comment', commentSchema);
