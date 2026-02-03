# Windows Activation Guide

This document covers Windows activation and the Start Menu shortcut with screenshots.

## 1. Activate Burp Suite Professional

Step 1.1: Enter your name (this appears as “License to You”).
<p align="center">
  <img src="img/licence1.png" alt="Activation step 1" width="720">
</p>

Step 1.2: Paste your `License Key`, then click `Next`.
<p align="center">
  <img src="img/licence2.png" alt="Activation step 2" width="720">
</p>

Step 1.3: Choose `Manual activation`.
<p align="center">
  <img src="img/licence3.png" alt="Activation step 3" width="720">
</p>

Step 1.4: Copy the `Request` from Burp’s Manual Activation window and paste it into `Activation Request` in `Loader.jar`.
<p align="center">
  <img src="img/licence4.png" alt="Activation step 4" width="720">
</p>
<p align="center">
  <img src="img/licence4.1.png" alt="Activation step 4.1" width="720">
</p>

Step 1.5: In `Loader.jar`, copy the `Activation Response`.
<p align="center">
  <img src="img/licence5.png" alt="Activation step 5" width="720">
</p>

Step 1.6: Paste the response into Burp’s Manual Activation window (`Paste Response`) and continue.
<p align="center">
  <img src="img/licence5.1.png" alt="Activation step 5.1" width="720">
</p>

Step 1.7: Burp Suite Pro is activated. If you want to launch via `loader.jar`, follow this:
<p align="center">
  <img src="img/licence6.png" alt="Activation step 6" width="720">
</p>

## 2. Start Menu Shortcut

`install.ps1` creates a Start Menu shortcut automatically (`BurpSuiteProfessional`).
To change the icon, edit the shortcut and select `burppro.ico` in `/BurpActivator`.

<p align="center">
  <img src="img/findburp.png" alt="Find Burp in Start Menu" width="720">
</p>
