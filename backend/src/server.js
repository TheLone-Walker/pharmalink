require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const { Server } = require('socket.io');
const { initSocket } = require('./services/socket.service');
const errorMiddleware = require('./middleware/error.middleware');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

initSocket(io);

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors());
app.use(morgan('dev'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.use('/api/auth',          require('./routes/auth.routes'));
app.use('/api/users',         require('./routes/user.routes'));
app.use('/api/medications',   require('./routes/medication.routes'));
app.use('/api/orders',        require('./routes/order.routes'));
app.use('/api/prescriptions', require('./routes/prescription.routes'));
app.use('/api/appointments',  require('./routes/appointment.routes'));
app.use('/api/deliveries',    require('./routes/delivery.routes'));
app.use('/api/pharmacies',    require('./routes/pharmacy.routes'));
app.use('/api/driver',        require('./routes/driver.routes'));
app.use('/api/doctor',        require('./routes/doctor.routes'));
app.use('/api/pharmacist',    require('./routes/pharmacist.routes'));
app.use('/api/admin',         require('./routes/admin.routes'));
app.use('/api/notifications', require('./routes/notification.routes'));
app.use('/api/complaints',    require('./routes/complaint.routes'));
app.use('/api/chat',          require('./routes/chat.routes'));
app.use('/api/reminders',     require('./routes/reminder.routes'));
app.use('/api/medical-history', require('./routes/prescription.routes'));
app.use('/api/transactions',  require('./routes/transaction.routes'));
app.use('/api/payments',      require('./routes/payment.routes'));
app.use('/api/push',          require('./routes/push.routes'));

app.get('/health', (req, res) => res.json({ status: 'ok', app: 'PharmaLink API' }));

app.use(errorMiddleware);

const PORT = process.env.PORT || 3000;
server.listen(PORT, async () => {
  console.log(`PharmaLink API running on port ${PORT}`);
  try {
    const { seedRegistry } = require('./utils/seedRegistry');
    await seedRegistry();
    console.log('ONMC & ONPC official registries initialized.');
  } catch (e) {
    console.warn('Registry seed notice:', e.message);
  }
});

module.exports = { app, io };
