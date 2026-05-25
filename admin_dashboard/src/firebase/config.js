import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getMessaging, isSupported } from "firebase/messaging";

// 🔧 Replace with your Firebase project config
const firebaseConfig = {
  apiKey: "AIzaSyAEVRKdzUBH7aLG7WCd6BmM5aW7WcUBvVY",
  appId: "1:558981992671:web:321471ffefdd3e76f5596a",
  messagingSenderId: "558981992671",
  projectId: "real-estate-9b23d",
  authDomain: "real-estate-9b23d.firebaseapp.com",
  storageBucket: "real-estate-9b23d.firebasestorage.app",
  measurementId: "G-B12JDF10CG",
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);

// FCM is optional — only init if browser supports it
export const getMessagingInstance = async () => {
  const supported = await isSupported();
  if (!supported) return null;
  return getMessaging(app);
};

export default app;
