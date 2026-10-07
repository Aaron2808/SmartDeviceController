# Smart Home Controller
 
An iOS app for controlling and monitoring smart home and IoT devices from a single interface. Built as my final year project for BSc Computer Science and Information Technology at the University of Galway.
 
## What it does
 
- **Control devices:** switch smart home and IoT devices on and off from the app.
- **Monitor energy use:** view device energy readings as charts.
- **Motion controls:** use the iPhone's motion sensors to control devices by moving the phone.
- **Automations:** set up condition-based rules, so a device responds automatically when a condition is met.
- **Timers:** schedule devices to turn on or off at a set time, with notifications.
<!-- TODO: add 2-3 screenshots here, e.g. ![Home screen](screenshots/home.png) -->
 
## How it works
 
The app talks to devices using **MQTT**, a lightweight messaging protocol commonly used in IoT. Devices and the app don't connect to each other directly. Instead, they all connect to a central **MQTT broker** (Eclipse Mosquitto), which runs on an **AWS EC2** server. The app publishes commands to topics that devices listen to, and subscribes to topics where devices publish their status and energy readings.
 
```
iPhone app  <--->  MQTT broker (Mosquitto on AWS EC2)  <--->  Smart devices
```
 
## Built with
 
- Swift and SwiftUI, developed in Xcode
- MQTT using the CocoaMQTT library
- Eclipse Mosquitto broker on AWS EC2
- Charts (Apple's Swift Charts framework) for energy graphs
- Core Motion for motion-based controls
- UserNotifications for timer alerts
