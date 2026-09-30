# RADAR.speed App Overview

RADAR.speed is a simple app that displays the speed of objects using the Garmin VARIA radar for cycling as a general speed check application. The application is simple in that the primary screen is to show the speed of objects that the radar is tracking.

This mobile app is iOS only and should be target only the latest iOS 26 APIs and the latest Swift deliverables. The app should also have an Apple Watch standalone app that can show the speed of vehicles on the watch from the VARIA without the iPhone.

Basic requirements:
1. The primary screen is a view of the radar field. Each vehicle is represented by a car icon from SF Symbols. 
2. There is a gear icon in the toolbar at the top. This accesses the settings sheet. Setting is where a Garmin Varia or other compatible can be linked. No other options are considered yet.
3. Differing from the Cyclometer app, this app assumes the user is at the bottom of the screen.
4. Each vehicle should show the live speed it is approaching next to the icon on the screen. 

Questions:
Does the Garmin RADAR show vehicles moving away from the RADAR or only coming towards?


