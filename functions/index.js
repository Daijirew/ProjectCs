// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();


console.log("Environment:", process.env.NODE_ENV || "production");
console.log("Firebase Functions initialized");

// ฟังก์ชันหลักสำหรับการตรวจสอบการจองที่หมดอายุ
const checkExpiredBookingsLogic = async () => {
  console.log("Checking for expired booking requests...");
  
  const now = admin.firestore.Timestamp.now();
  console.log("Current time:", now.toDate());
  
  // ค้นหาคำขอที่หมดเวลา
 const pendingBookingsSnapshot = await admin.firestore()
  .collection("bookings")
  .where("status", "==", "pending")
  .get();

// ทำการตรวจสอบเวลาหมดอายุเอง
const expiredRequests = [];
pendingBookingsSnapshot.forEach(doc => {
  const data = doc.data();
  // ตรวจสอบว่ามี expirationTime หรือไม่
  if (data.expirationTime) {
    // ตรวจสอบว่าเวลาหมดอายุผ่านไปแล้วหรือไม่
    if (data.expirationTime.toMillis() < now.toMillis()) {
      console.log(`Found expired booking: ${doc.id}, expired at ${data.expirationTime.toDate()}`);
      expiredRequests.push(doc);
    }
  } else {
    console.log(`Booking ${doc.id} does not have an expiration time`);
  }
});

console.log(`Found ${expiredRequests.length} expired requests`);
  
  const batch = admin.firestore().batch();
  const promises = [];
  const deletedBookings = [];
  
  expiredRequestsSnapshot.forEach((doc) => {
    const bookingId = doc.id;
    const data = doc.data();
    const userId = data.userId;
    const sitterId = data.sitterId;
    
    console.log(`Processing expired booking: ${bookingId}`);
    
    // เก็บข้อมูลคำขอที่จะถูกลบไว้ในอาร์เรย์ก่อน
    deletedBookings.push({
      id: bookingId,
      ...data,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      reason: "คำขอหมดเวลาอัตโนมัติหลังจาก 1 นาที",
    });
    
    // ลบคำขอจาก collection bookings
    batch.delete(doc.ref);
    
    // สร้างการแจ้งเตือนให้ผู้ใช้
    const userNotification = {
      title: "คำขอการจองหมดเวลาและถูกลบแล้ว",
      message: "คำขอการจองของคุณได้หมดเวลาและถูกลบออกจากระบบ กรุณาทำรายการใหม่อีกครั้ง",
      type: "booking_deleted",
      bookingId: bookingId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    // เพิ่มการแจ้งเตือนในระบบหลักเมื่อคำขอหมดเวลา
// เพิ่มการแจ้งเตือนเมื่อคำขอหมดเวลา
const mainNotification = {
  title: "คำขอหมดอายุ",
  message: bookingId,
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  isRead: false,
};

const mainNotifRef = admin.firestore()
    .collection("notifications")
    .doc();
batch.set(mainNotifRef, mainNotification);
    
    // เพิ่มการแจ้งเตือนใน batch
    const userNotifRef = admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();
    batch.set(userNotifRef, userNotification);
    
    if (sitterId) {
      // สร้างการแจ้งเตือนให้ผู้รับเลี้ยง
      const sitterNotification = {
        title: "คำขอการจองหมดเวลาและถูกลบแล้ว",
        message: "คำขอการจองได้หมดเวลาและถูกลบออกจากระบบ",
        type: "booking_deleted",
        bookingId: bookingId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      };
      
      const sitterNotifRef = admin.firestore()
          .collection("users")
          .doc(sitterId)
          .collection("notifications")
          .doc();
      batch.set(sitterNotifRef, sitterNotification);
    }
    
    // สร้างการแจ้งเตือนให้แอดมิน
    const adminNotification = {
      title: "คำขอการจองหมดเวลาและถูกลบแล้ว",
      message: `คำขอการจอง ${bookingId} ได้หมดเวลาและถูกลบออกจากระบบโดยอัตโนมัติ`,
      type: "booking_deleted",
      bookingId: bookingId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    };
    
    const adminNotifRef = admin.firestore()
        .collection("admin_notifications")
        .doc();
    batch.set(adminNotifRef, adminNotification);
    
    // ส่ง push notification (ถ้ามี FCM token)
    if (userId && sitterId) {
      promises.push(sendPushNotifications(userId, sitterId, bookingId));
    }
  });
  
  // เพิ่มประวัติการลบลงในคอลเลคชัน deleted_bookings
  for (const deletedBooking of deletedBookings) {
    const deletedBookingRef = admin.firestore()
      .collection("deleted_bookings")
      .doc(deletedBooking.id);
    batch.set(deletedBookingRef, deletedBooking);
  }
  
  // ดำเนินการทั้งหมดพร้อมกัน
  await batch.commit();
  if (promises.length > 0) {
    await Promise.all(promises);
  }
  
  console.log(`Successfully deleted ${deletedBookings.length} expired bookings`);
  return { 
    success: true, 
    processedCount: expiredRequestsSnapshot.size,
    deletedCount: deletedBookings.length
  };
};
// เพิ่มฟังก์ชันที่เรียกได้จาก Firebase Console เพื่อตรวจสอบเวลา
exports.testTimestamp = functions.https.onRequest(async (req, res) => {
  try {
    const now = admin.firestore.Timestamp.now();
    const nowDate = now.toDate();
    
    // แสดงข้อมูลเวลาปัจจุบัน
    const timeInfo = {
      timestamp: now,
      date: nowDate.toString(),
      milliseconds: now.toMillis(),
      timezoneOffset: nowDate.getTimezoneOffset(),
    };
    
    // ตรวจสอบการจองที่มีสถานะ pending
    const pendingBookings = await admin.firestore()
      .collection("bookings")
      .where("status", "==", "pending")
      .get();
      
    const bookingsData = [];
    
    pendingBookings.forEach(doc => {
      const data = doc.data();
      const expirationTime = data.expirationTime || null;
      const expirationDate = expirationTime ? expirationTime.toDate() : null;
      const isExpired = expirationTime ? expirationTime.toMillis() < now.toMillis() : false;
      
      bookingsData.push({
        id: doc.id,
        expirationTime: expirationTime,
        expirationDate: expirationDate ? expirationDate.toString() : null,
        isExpired: isExpired,
        shouldBeProcessed: isExpired,
      });
    });
    
    res.status(200).json({
      success: true,
      serverTime: timeInfo,
      pendingBookingsCount: pendingBookings.size,
      bookings: bookingsData,
    });
  } catch (error) {
    console.error("Error in testTimestamp:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});
// เพิ่มฟังก์ชันตรวจสอบคำขอหมดเวลาทุกครั้งที่มีการสร้างหรือแก้ไขการจอง
exports.watchNewBookings = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    try {
      const bookingData = snapshot.data();
      const bookingId = context.params.bookingId;
      
      // ตรวจสอบว่ามีการตั้ง expirationTime หรือไม่
      if (!bookingData.expirationTime) {
        console.log(`Booking ${bookingId} does not have an expiration time. Setting it now.`);
        
        // ถ้าไม่มี ให้ตั้งเวลาหมดอายุเป็น 15 นาทีจากปัจจุบัน
        const expirationTime = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 1 * 60 * 1000) // 15 นาที
        );
        
        await snapshot.ref.update({
          expirationTime: expirationTime
        });
      }
      
      // ตั้งเวลาเพื่อตรวจสอบคำขอนี้โดยเฉพาะเมื่อถึงเวลาหมดอายุ
      const expirationTime = bookingData.expirationTime.toDate();
      const now = new Date();
      
      // คำนวณเวลาที่ต้องรอจนถึงเวลาหมดอายุ (หน่วยเป็น ms)
      const delayMs = Math.max(0, expirationTime.getTime() - now.getTime());
      
      console.log(`Booking ${bookingId} will expire at ${expirationTime}, setting timer for ${delayMs / 1000} seconds`);
      
      // ตั้งเวลา (ถ้าเลยเวลาหมดอายุแล้ว ให้ตรวจสอบทันที)
      setTimeout(async () => {
        // ตรวจสอบว่าการจองยังอยู่ในสถานะ pending หรือไม่
        const bookingSnapshot = await admin.firestore()
          .collection('bookings')
          .doc(bookingId)
          .get();
          
        if (bookingSnapshot.exists) {
          const currentData = bookingSnapshot.data();
          
          if (currentData.status === 'pending') {
            console.log(`Booking ${bookingId} has expired, running check now`);
            await checkExpiredBookingsLogic();
          }
        }
      }, delayMs);
      
      return null;
    } catch (error) {
      console.error("Error in watchNewBookings:", error);
      return null;
    }
  });
// สร้างฟังก์ชัน HTTP สำหรับการทดสอบบน emulator
exports.checkExpiredBookings = functions.pubsub
  .schedule('every 20 seconds')
  .timeZone('Asia/Bangkok') // ตั้งเวลาเป็นเขตเวลาของประเทศไทย
  .onRun(async (context) => {
    try {
      console.log("Starting expired bookings check...");
      const result = await checkExpiredBookingsLogic();
      console.log("Completed expired bookings check. Processed:", result.processedCount);
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      return null;
    }
  });
/**
 * ฟังก์ชันส่ง push notification
 * @param {string} userId - ไอดีของผู้ใช้
 * @param {string} sitterId - ไอดีของผู้รับเลี้ยง
 * @param {string} bookingId - ไอดีของการจอง
 * @return {Promise} Promise ของการส่งการแจ้งเตือน
 */
async function sendPushNotifications(userId, sitterId, bookingId) {
  try {
    // ตรวจสอบว่ามีค่า userId และ sitterId หรือไม่
    if (!userId || !sitterId) {
      console.log("Missing userId or sitterId, skipping push notifications");
      return;
    }
    
    // ดึงข้อมูลผู้ใช้
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();
    
    // ดึงข้อมูลผู้รับเลี้ยง
    const sitterDoc = await admin.firestore()
        .collection("users")
        .doc(sitterId)
        .get();
    
    // ตรวจสอบว่าเอกสารมีอยู่จริง
    if (!userDoc.exists || !sitterDoc.exists) {
      console.log("User or sitter document not found");
      return;
    }
    
    const userData = userDoc.data();
    const sitterData = sitterDoc.data();
    
    // ส่งการแจ้งเตือนเฉพาะเมื่อมี FCM token
    if (userData && userData.fcmToken) {
      try {
        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: "คำขอการจองหมดเวลาและถูกลบแล้ว",
            body: "คำขอการจองของคุณได้หมดเวลาและถูกลบออกจากระบบ กรุณาทำรายการใหม่อีกครั้ง",
          },
          data: {
            type: "booking_deleted",
            bookingId: bookingId,
          },
        });
        console.log("Sent notification to user", userId);
      } catch (err) {
        console.error("Failed to send notification to user:", err);
      }
    }
    
    if (sitterData && sitterData.fcmToken) {
      try {
        await admin.messaging().send({
          token: sitterData.fcmToken,
          notification: {
            title: "คำขอการจองหมดเวลาและถูกลบแล้ว",
            body: "คำขอการจองได้หมดเวลาและถูกลบออกจากระบบ",
          },
          data: {
            type: "booking_deleted",
            bookingId: bookingId,
          },
        });
        console.log("Sent notification to sitter", sitterId);
      } catch (err) {
        console.error("Failed to send notification to sitter:", err);
      }
    }
  } catch (error) {
    console.error("Error in sendPushNotifications:", error);
  }
}
// แก้ไขฟังก์ชัน Firestore Trigger
exports.checkExpiredBookingsByFirestore = functions.firestore
  .document('triggers/checkExpiredBookings')
  .onWrite(async (change, context) => {
    try {
      console.log("Firestore trigger activated for expired bookings check");
      const result = await checkExpiredBookingsLogic();
      console.log("Expired bookings check completed:", result);
      
      // อัพเดตเอกสาร trigger เพื่อบันทึกผลลัพธ์
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .update({
          lastRun: admin.firestore.FieldValue.serverTimestamp(),
          lastResult: result,
          processedCount: result.processedCount
        });
      
      return null;
    } catch (error) {
      console.error("Error checking expired bookings:", error);
      
      // บันทึกข้อผิดพลาด
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .update({
          lastRun: admin.firestore.FieldValue.serverTimestamp(),
          lastError: error.message
        });
      
      return null;
    }
  });

  // เพิ่มฟังก์ชันใหม่
exports.initializeBookingTriggers = functions.https.onRequest(async (req, res) => {
  try {
    // ตรวจสอบว่าเอกสารมีอยู่แล้วหรือไม่
    const triggerDoc = await admin.firestore()
      .collection('triggers')
      .doc('checkExpiredBookings')
      .get();
      
    if (!triggerDoc.exists) {
      // ถ้ายังไม่มีเอกสาร ให้สร้างใหม่
      await admin.firestore()
        .collection('triggers')
        .doc('checkExpiredBookings')
        .set({
          lastTriggered: admin.firestore.FieldValue.serverTimestamp(),
          initialized: true
        });
      console.log("Created initial trigger document");
    }
    
    res.status(200).send("Booking triggers initialized successfully");
  } catch (error) {
    console.error("Error initializing booking triggers:", error);
    res.status(500).send("Error initializing booking triggers: " + error.message);
  }
});