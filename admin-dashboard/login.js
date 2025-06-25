const firebaseConfig = {
    apiKey: "AIzaSyB9wGxHUOWy1m4aVOvEBz0jK9qIppn0Psk",
    authDomain: "mafioso-69a40.firebaseapp.com",
    databaseURL: "https://mafioso-69a40-default-rtdb.firebaseio.com",
    projectId: "mafioso-69a40",
    storageBucket: "mafioso-69a40.appspot.com",
    messagingSenderId: "799095141701",
    appId: "1:799095141701:web:8703ee32aa5616f0ccfa2c",
    measurementId: "G-CGWB20E6CE"
};

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();

const loginForm = document.getElementById('login-form');
const emailInput = document.getElementById('email');
const passwordInput = document.getElementById('password');
const errorMessageDiv = document.getElementById('error-message');

loginForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const email = emailInput.value;
    const password = passwordInput.value;

    auth.signInWithEmailAndPassword(email, password)
        .then((userCredential) => {
            // Signed in 
            window.location.href = 'index.html';
        })
        .catch((error) => {
            errorMessageDiv.style.display = 'block';
            errorMessageDiv.innerText = 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
            console.error("Login Error:", error);
        });
}); 