const { emitToUser } = require('./socket.service');
const prisma = require('../config/db');

const send = async (userId, title, body, type = 'general', data = {}) => {
  const notification = await prisma.notification.create({
    data: { userId, title, body, type, data },
  });
  emitToUser(userId, 'notification:new', notification);
  // Trigger instant app refresh
  emitToUser(userId, 'user:refresh', { userId });
  return notification;
};

const sendToMany = async (userIds, title, body, type = 'general') => {
  await Promise.all(userIds.map((userId) => send(userId, title, body, type)));
};

module.exports = { send, sendToMany };
