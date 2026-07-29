const express = require('express');
const router = express.Router();
const commentController = require('../controllers/commentController');
const auth = require('../middleware/auth');
const commentRateLimiter = require('../middleware/rateLimiter');

// Public read endpoints
router.get('/', commentController.getRootComments);
router.get('/all', commentController.getAllComments);
router.get('/search', commentController.searchComments);
router.get('/events', commentController.getMissedEvents);

// Protected write endpoints
router.post('/', auth, commentRateLimiter, commentController.createComment);
router.put('/:id', auth, commentController.editComment);
router.delete('/:id', auth, commentController.deleteComment);
router.post('/:id/like', auth, commentController.toggleLike);

module.exports = router;
