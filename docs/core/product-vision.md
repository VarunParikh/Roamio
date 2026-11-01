# Product vision: Roamio

The owner's original brief, unchanged apart from being converted to text. The original file is [`docs/inputs/roamio-product-vision.rtf`](../inputs/roamio-product-vision.rtf). Where this differs from what was built, see the [conflicts log](open-conflicts.md).

---

Here is the new vision for the product: 	A travel partner application for solo, couple or group travellers. This application will be useful in splitting bills and maintaining travel log of spends and documents (Ex: bills, receipts, tickets etc)
Name of the application:
	Roamio
Tagline:
	Split bills. Not Friendships
Sub-tagline:
	Instant peer splits. Zero Awkward  Math.
Use cases - 	Users will need to log in to the application, using single sign-on via their Gmail/Apple ID or will create the account via email and password.
	A new user (Example: ‘User A’) who wants to start an adventure:
		Once a ‘User A’ is logged in, the user will see the existing adventures. If their are no adventures present, then a user can click on a button called ‘New Adventure’
		‘User A’ will add a description for the new adventure: Example - name of the place to be visited (Country, city etc). Will add a text for the Adventure (Example: College group’s Bangkok adventure)
		‘User A’ will now be asked to either add the squad (new users), a sharable link will be generated. The user will be able to copy this link and share it with their squad on other existing messaging apps. NOTE: These users will need to have the application pre installed and a logged in.
		This user (User A) will become the ‘Squad Leader’ as this is the user who initiated the adventure.
	A new user (Example ‘User B’) who has received an invite via a link to join an adventure from ‘User A’:
		‘User B’ receives a link to join adventure <Adventure name>, ‘User B’ will click on the link --> install the app —> open the app —> create an account  and  view all the awaiting adventures they need to be a part of.
		‘User B’ will click on the adventure from the list and will now be a part of the respective adventure’s squad.
	Creating a new co-squad leader:
		Since ‘User A’ was the squad leader
		User A will see a Squad member has been added to the squad
		User A will be able to either be ‘kick out’ (remove) or assign this user as a ‘co-squad lead’
	Creating a pseudo user / pal:
		A squad leader or a co-squad lead can create a pseudo user called ‘pal’
		A pal is a user who presents with the user during their adventures but the user does not have access to the application.
		A pal will always be dependent on users who have access to the application.
	Add an adventure:
		Any user with access to the application can create an adventure
		Each user who is a part of the squad can add their personal budget to the adventure - a user’s personal budget will be hidden from other users.
	Adding a tab:
		Any user (except a pal- as they do not have access to the app) will be able to create a tab
	Splits:
		Any user can view the latest split report which would be linked to the adventure
	Alert / Notification
		Alert user when their personal budget limit has been reached

	What all data will be accessed from the internet:
		The banner of the adventure will be downloaded from the Internet and loaded as default based on the country selected - fetch from the internet, compress and upload. Ensure this is cached and loaded instantly.
		The default local currency will be fetched based on the country selected.
		Weather for users location
	Data in a user profile:
		Upload user personal photo via Camera or phone gallery
		User name (fetch from gmail) editable
		User description (optional)

	Data in adventure details:
		Country name
		Start date and end date
		Auto download banner photo (based on country selected)
			User can edit the banner photo by uploading their own photo via camera or phone gallery (Optional)
		Auto populate (editable) currency details
		Adventure description (Optional)
	Data in expense ‘Tab’:
		Click picture to fetch bill details (OCR) - auto populate relevant fields (Optional)
		Tab description (Optional)
		Tab amount
		Tab currency (Default to the default currency for the adventure)
		Tab date (auto populate the current date but must be editable by the user)
		Select users from the squad who are a part of the tab (Allow multi-select)
		Add pseudo user (for the tab) (Optional)
		Add 4 memories to the tab (Upload via camera / phone gallery) (Optional)
		Fetch users location and save location details (Optional)
	Rights of a squad lead / co-squad lead:
		Add / Edit adventure’s metadata- Name, duration, default picture, adding/ removing users (including pseudo users).
	Access:
		Online and offline
		Offline:
			Sync once user clicks on a button to sync
			text below the button “We know the data might be of essence, click here to sync the adventure with your squad”
	Currency conversion:
		User will be able to add expanse in any currency they want but will be able to see the settlement in the currency which is set up as default in their profile.
		Use an existing API for currency conversation
Application screens:
	Splash screen
	Login page
	Create account
	User Profile (‘You’)
	Home page
	Adventure page - list all the tabs
	Adventure Creation page
	Add tab page
	Split (Current split details- a small dashboard user wise split, activity wise expanse till now,  day expanse till now, user level - allow user to download pdf or excel sheet.
Bottom menu:
	Home - welcome message, Existing adventure (‘Hero’) and upcoming adventures & list of invites
	Split (view current status) - Select between overall (historical spends for the user and per adventure - user can click on an adventure to view split dashboard for the specific adventure) If there is an active adventure, then the default view will be that of an adventure
	You (User Profile)
Application platform:
	Android - Phase 1
	Web - Phase 2
	iOS - Phase 3
Target users:
	Young travellers - Solo, couple, group.
Animations:
	Use subtle animations to attract user attention on buttons which need to be clicked for the job to be done in the required user journey.
UI:
	Fetch sample screens and design.md from /Users/varunparikh/Projects/Roamio-travel-partner/stitch_android_app_ui_replica on this computer.
	Ensure the same UI pattern followed.
	NOTE: This UI is to be used for colour schemes and overall presentation but not for app use cases.
	Users who are squad leader or co-squad lead will have a hat emoji added on top of their profile picture for an adventure.
UX:
	Use subtle animations to attract user attention on buttons which need to be clicked on next.
	Ensure the user journey is simple and there is only 1 important button on a screen at a time.
	Ensure the user is never overwhelmed with access data at 1st glance. Data can be provided as and when the user asks for the data to be shown.
	Ensure the UX is more rounded, playful, youthful and fun to use.
	Elements in the UI must interact with one another - Example: the bottom part of the screen can be scrolled on top of the top of the screen
	Ensure there are no dead user journeys
Architecture:
	Ensure the elements are configurable from the backend by the developer - to make sure there aren’t multiple updates to make small changes
	Ensure a notification popup to download a new version of the application if available on the below git hub repo
	Ensure the photos are compressed without losing quality before uploading on database.
Pilot and test:
	Android app
	Number of users: 10

Important for the project:
Follow the AI software development lifecycle
Documentation
All use cases must function as intended
Edge cases must be handled
Entire project must be available on GitHub

Compliances:
	Ensure GDPR compliance  ??
Data:
	Identify the required data points from  /Users/varunparikh/Projects/Roamio-travel-partner/Data
	Relevant data will need to be encrypted at rest and transit
System:
I am using a MacBook M5 16Gb RAM 1TB SSD
Claude code to be used for development wherever needed.


Checks:
	Photos uploaded by the users will be compressed before uploading on DB - to ensure space saving.
	Users will be using their latest phones to click and upload pictures (These phone cameras will have high resolution, hence the picture size will be too large)


App dictionary:
	Adventure: is a trip that user has decided to go to
	Squad: User can add more users / guests to their trip/adventure
	Squad-leader / co- squad lead: Admin for the trip/adventure
	Pal: A guest user who is added to the squad/group for a specific trip
	Tab: An expense which the user has created within a trip. A tab can contain a single user from the squad / multiple users from the squad / all the squad members.
	Split: Amount which needs to be split amongst the squad
	Memory: Photo upload

Repo to be used:
	https://github.com/VarunParikh/Roamio
Future viersions:
	Adding payment gateway - allow users to directly pay from within the app
	Create an explore page - to help users identify near by activities (fetch from internet)
	Web app and iOS app
	Gamification
	Identify and flag duplicate tabs
Handhold me through the process, automate the operations for this project as much as possible.
