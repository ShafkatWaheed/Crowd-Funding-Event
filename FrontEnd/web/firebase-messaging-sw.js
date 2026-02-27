importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBzMzx9blEMlDZt-nbiRcbyW69t5KDOktE",
  authDomain: "crowd-funding-event.firebaseapp.com",
  projectId: "crowd-funding-event",
  storageBucket: "crowd-funding-event.firebasestorage.app",
  messagingSenderId: "91132364478",
  appId: "1:91132364478:web:d87b090113f550a1f280ef",
  measurementId: "G-36QJN3NM3F",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || "New notification";
  const options = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png",
  };
  return self.registration.showNotification(title, options);
});
