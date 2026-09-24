const router = require('express').Router();
const prisma = require('../config/db');
const { authenticate } = require('../middleware/auth.middleware');
const geminiService = require('../services/gemini.service');

// AI Health Assistant Chat
router.post('/gemini', authenticate, async (req, res, next) => {
  try {
    const { message, context } = req.body;
    const reply = await geminiService.chat(message, context || '');
    res.json({ success: true, data: { reply } });
  } catch (err) { next(err); }
});

// Get all active conversation threads for the current user
router.get('/conversations', authenticate, async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Find all messages involving this user
    const messages = await prisma.message.findMany({
      where: {
        OR: [{ senderId: userId }, { receiverId: userId }],
      },
      include: {
        sender: {
          select: {
            id: true,
            name: true,
            role: true,
            profilePhotoUrl: true,
            doctorProfile: { select: { specialty: true, hospital: true } },
            pharmacistProfile: { select: { pharmacyName: true } },
            driverProfile: { select: { vehicleInfo: true } },
          },
        },
        receiver: {
          select: {
            id: true,
            name: true,
            role: true,
            profilePhotoUrl: true,
            doctorProfile: { select: { specialty: true, hospital: true } },
            pharmacistProfile: { select: { pharmacyName: true } },
            driverProfile: { select: { vehicleInfo: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const conversationMap = new Map();

    for (const msg of messages) {
      const isSender = msg.senderId === userId;
      const partner = isSender ? msg.receiver : msg.sender;
      if (!partner) continue;

      if (!conversationMap.has(partner.id)) {
        let subtitle = partner.role;
        if (partner.doctorProfile) subtitle = `Dr. • ${partner.doctorProfile.specialty || partner.doctorProfile.hospital || 'Doctor'}`;
        else if (partner.pharmacistProfile) subtitle = partner.pharmacistProfile.pharmacyName || 'Pharmacy';
        else if (partner.driverProfile) subtitle = `Driver • ${partner.driverProfile.vehicleInfo || 'Motorbike'}`;
        else if (partner.role === 'admin') subtitle = 'PharmaLink Support Admin';
        else subtitle = 'Patient';

        conversationMap.set(partner.id, {
          userId: partner.id,
          name: partner.name,
          role: partner.role,
          subtitle,
          profilePhotoUrl: partner.profilePhotoUrl,
          lastMessage: msg.content,
          lastMessageTime: msg.createdAt,
          unread: !isSender && !msg.isRead,
        });
      }
    }

    const conversations = Array.from(conversationMap.values());
    res.json({ success: true, data: conversations });
  } catch (err) { next(err); }
});

// Get contacts available to chat with
router.get('/contacts', authenticate, async (req, res, next) => {
  try {
    const role = req.user.role;
    const users = await prisma.user.findMany({
      where: {
        id: { not: req.user.id },
        isActive: true,
      },
      select: {
        id: true,
        name: true,
        role: true,
        phone: true,
        email: true,
        profilePhotoUrl: true,
        doctorProfile: { select: { specialty: true, hospital: true } },
        pharmacistProfile: { select: { pharmacyName: true, pharmacyAddress: true } },
        driverProfile: { select: { vehicleInfo: true, isOnline: true } },
      },
      orderBy: { name: 'asc' },
      take: 60,
    });

    const contacts = users.map(u => {
      let subtitle = u.role.toUpperCase();
      if (u.doctorProfile) subtitle = `Dr. • ${u.doctorProfile.specialty || 'General Practitioner'}`;
      else if (u.pharmacistProfile) subtitle = u.pharmacistProfile.pharmacyName || 'Pharmacy';
      else if (u.driverProfile) subtitle = `Driver • ${u.driverProfile.vehicleInfo || 'Motorbike'}`;
      else if (u.role === 'admin') subtitle = '24/7 Support Desk';
      else subtitle = 'Patient';

      return {
        id: u.id,
        name: u.name,
        role: u.role,
        subtitle,
        phone: u.phone,
        profilePhotoUrl: u.profilePhotoUrl,
      };
    });

    res.json({ success: true, data: contacts });
  } catch (err) { next(err); }
});

// Get messages between current user and specific user
router.get('/messages/:userId', authenticate, async (req, res, next) => {
  try {
    const messages = await prisma.message.findMany({
      where: {
        OR: [
          { senderId: req.user.id, receiverId: req.params.userId },
          { senderId: req.params.userId, receiverId: req.user.id },
        ],
      },
      orderBy: { createdAt: 'asc' },
    });

    // Mark messages as read
    await prisma.message.updateMany({
      where: {
        senderId: req.params.userId,
        receiverId: req.user.id,
        isRead: false,
      },
      data: { isRead: true },
    }).catch(() => {});

    res.json({ success: true, data: messages });
  } catch (err) { next(err); }
});

// Send message
router.post('/messages', authenticate, async (req, res, next) => {
  try {
    const { receiverId, content, orderId } = req.body;
    if (!receiverId || !content) {
      return res.status(400).json({ success: false, message: 'receiverId and content required' });
    }

    const message = await prisma.message.create({
      data: { senderId: req.user.id, receiverId, content, orderId },
      include: {
        sender: { select: { id: true, name: true, role: true } },
      },
    });

    res.status(201).json({ success: true, data: message });
  } catch (err) { next(err); }
});

module.exports = router;
