// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getDatabase } from "firebase/database";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyDh3Ym2EqQvv6Mtc6aH_4ryjf0Q614Eq7k",
  authDomain: "civichero-480a3.firebaseapp.com",
  databaseURL: "https://civichero-480a3-default-rtdb.firebaseio.com",
  projectId: "civichero-480a3",
  storageBucket: "civichero-480a3.firebasestorage.app",
  messagingSenderId: "727957080527",
  appId: "1:727957080527:web:your-web-app-id"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase Authentication and get a reference to the service
export const auth = getAuth(app);

// Initialize Realtime Database and get a reference to the service
export const database = getDatabase(app);
