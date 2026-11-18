# calendar reimagined

an iphone calendar built with swiftui and eventkit. pick a day on the left, see its events on the right, and open an event to edit it.

## demo

the screenshots and recording use fictional events.

the video shows the app in a mac catalyst preview.

| agenda | event |
| --- | --- |
| <img src="docs/media/agenda.png" alt="weekly agenda" width="220"> | <img src="docs/media/event.png" alt="event details" width="220"> |

[watch the screen recording](docs/media/demo.mp4)

## using it

- tap or drag along the date rail to select a day. swipe across it to change weeks.
- tap the plus button to add an event. choose its calendar, dates, location, notes, and colour.
- open an event to edit it, copy its details, share it, or delete it.
- timed, overnight, and all-day events appear on the days they cover. changes from apple calendar show up while the app is open.

events save to the calendars already set up on your iphone. allow full calendar access when asked. if you deny access, use the app's settings button to enable it later. adding events also requires a writable calendar in the calendar app.

## running it

1. open `calendarreimagined.xcodeproj` in xcode with the ios 27 sdk installed.
2. select the `calendarreimagined` scheme and an iphone simulator or connected iphone running ios 27 or later.
3. select your signing team if running on a physical iphone, then run the app.

the [unsigned ipa](https://github.com/kevinsstinc/calendar-remade/releases/tag/v1.0.0) needs signing before installation.

the app uses a light appearance. read-only calendars can be viewed. edits and deletes to recurring events affect the selected occurrence. custom event colours and events saved by older local-only versions stay in the app.
