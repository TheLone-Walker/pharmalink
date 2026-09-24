let ioInstance;

const initSocket = (io) => {
  ioInstance = io;
  io.on('connection', (socket) => {
    console.log('⚡ Socket connected:', socket.id);

    // Join user room
    socket.on('join_room', (userId) => {
      if (userId) {
        socket.join(`user_${userId}`);
        console.log(`👤 User ${userId} joined room user_${userId}`);
      }
    });

    // Join role-specific room (patient, doctor, pharmacist, delivery_driver, admin)
    socket.on('join_role', (role) => {
      if (role) {
        socket.join(`role_${role}`);
        console.log(`🏷️ Socket ${socket.id} joined role_${role}`);
      }
    });

    // Join pharmacy room
    socket.on('join_pharmacy', (pharmacyId) => {
      if (pharmacyId) {
        socket.join(`pharmacy_${pharmacyId}`);
        console.log(`🏥 Pharmacy ${pharmacyId} joined room pharmacy_${pharmacyId}`);
      }
    });

    socket.on('driver:location_update', (data) => {
      // data: { orderId, lat, lng }
      if (data && data.orderId) {
        io.to(`order_${data.orderId}`).emit('driver:location', data);
      }
    });

    socket.on('join_order', (orderId) => {
      if (orderId) {
        socket.join(`order_${orderId}`);
      }
    });

    socket.on('chat:message', (data) => {
      // data: { senderId, receiverId, content, orderId }
      if (data && data.receiverId) {
        io.to(`user_${data.receiverId}`).emit('chat:message', data);
      }
    });

    socket.on('disconnect', () => {
      console.log('🔌 Socket disconnected:', socket.id);
    });
  });
};

const emitToUser = (userId, event, data) => {
  if (ioInstance && userId) {
    ioInstance.to(`user_${userId}`).emit(event, data);
  }
};

const emitToPharmacy = (pharmacyId, event, data) => {
  if (ioInstance && pharmacyId) {
    ioInstance.to(`pharmacy_${pharmacyId}`).emit(event, data);
  }
};

const emitToRole = (role, event, data) => {
  if (ioInstance && role) {
    ioInstance.to(`role_${role}`).emit(event, data);
  }
};

const emitToOrder = (orderId, event, data) => {
  if (ioInstance && orderId) {
    ioInstance.to(`order_${orderId}`).emit(event, data);
  }
};

const broadcastGlobal = (event, data) => {
  if (ioInstance) {
    ioInstance.emit(event, data);
  }
};

module.exports = {
  initSocket,
  emitToUser,
  emitToPharmacy,
  emitToRole,
  emitToOrder,
  broadcastGlobal,
};
