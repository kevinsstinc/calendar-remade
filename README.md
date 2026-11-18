# calendar reimagined

**ai-assisted with codex and chatgpt**

an iphone calendar built with swiftui and eventkit. pick a date using the rail on the left, see its events on the right, and add new events to apple calendar.

## demo

the screenshots and recording use fictional events.

the video shows the app in a mac catalyst preview. the demo is from an earlier version, so it may show features that aren't in the simplified build.

<img width="322" height="688" alt="calendar reimagined screenshot" src="https://github.com/user-attachments/assets/ce33228d-aa5c-4649-b0e3-fad85a6319a5" />

https://github.com/user-attachments/assets/32fd2641-7387-431e-9683-7ab23d138fae

## using it

- select a day using the date rail. swipe across it to move between weeks.
- view events for that day, including their times and locations when available. all-day events are labelled separately.
- tap the plus button to add an event with a title, start and end times, and an optional location.
- new events are saved to your default writable calendar in apple calendar.
- events spanning more than one day can appear on each relevant day. the list reloads when you change dates or return to the app.

the app needs full calendar access to display and add events. if you deny access, use the **open settings** button to change the permission later. you also need a writable default calendar set up in apple calendar to add events.

this simplified version only lists and adds events. it does not support editing, deleting, sharing, custom event colours, notes, or choosing a different calendar when adding an event. event colours in the list come from apple calendar. events saved only in older local versions aren't imported.

## sideloading

requires an iphone running ios 27 or later and a mac or windows computer. download `calendarreimagined-unsigned.ipa` from the [latest release](https://github.com/kevinsstinc/calendar-remade/releases/latest). the ipa needs to be signed before it can run on your iphone.

1. install altserver. on windows, follow the itunes and icloud requirements in its guide. see the official [macos guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos) or [windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
2. connect your iphone using usb, unlock it, and trust the computer.
3. hold **option** on macos or **shift** on windows while clicking the altserver icon. select **sideload .ipa…**, choose your iphone and the downloaded ipa, and sign in when prompted. see the [altserver instructions](https://faq.altstore.io/release-notes/altserver#direct-ipa-sideloading).
4. on your iphone, trust your developer account under **settings → general → vpn & device management**. enable developer mode under **settings → privacy & security** if prompted, restart, and confirm it. see the [developer mode guide](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device).

with a free apple account, apps sideloaded directly through altserver need to be reinstalled every seven days. altstore classic can help with app refreshes through altserver. see [refreshing apps](https://faq.altstore.io/altstore-classic/your-altstore) and [connecting to altserver](https://faq.altstore.io/altstore-classic/altserver).

## running from source

1. open `calendarreimagined.xcodeproj` in xcode with the ios 27 sdk installed.
2. select the `calendarreimagined` scheme and an iphone simulator or connected iphone running ios 27 or later.
3. choose your signing team if using a physical iphone, then run the app.

the app uses a light appearance and reads events from the calendars already on your iphone, including read-only calendars. adding events requires calendar write access.

## ai use

codex helped with the earlier eventkit implementation, refactoring, build checks, and release preparation. chatgpt helped rewrite the simpler list-and-add implementation and update this readme. this is an ai-assisted project.
