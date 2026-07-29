// Rate-limit POST /comments to 1 request per 3 seconds per authenticated user

const userLastPostTime = new Map();

const commentRateLimiter = (req, res, next) => {
  const userId = req.user?.id;
  if (!userId) {
    return res.status(401).json({ error: 'Authentication required.' });
  }

  const now = Date.now();
  const lastTime = userLastPostTime.get(userId);

  if (lastTime && now - lastTime < 3000) {
    const remainingSeconds = Math.ceil((3000 - (now - lastTime)) / 1000);
    return res.status(429).json({
      error: `Rate limit exceeded. Please wait ${remainingSeconds} second(s) before posting again.`,
      retryAfter: remainingSeconds,
    });
  }

  userLastPostTime.set(userId, now);

  // Clean up old entries periodically to prevent memory leaks
  if (userLastPostTime.size > 10000) {
    const cutoff = now - 10000;
    for (const [uid, timestamp] of userLastPostTime.entries()) {
      if (timestamp < cutoff) {
        userLastPostTime.delete(uid);
      }
    }
  }

  next();
};

module.exports = commentRateLimiter;
