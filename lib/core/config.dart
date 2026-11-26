/// Public GitHub repo that hosts your release APKs, e.g. 'danishskh70/fish-journal-apk'.
/// Leave empty to switch the update notice off.
const githubRepo = 'danishskh70/fishjournalapp';

/// What's new text, shown once after the app is updated. Add one entry per release.
const Map<String, List<String>> changelog = {
  '1.1.2': [
    'Faster loading with data caching',
    'Improved pull-to-refresh and automatic data refresh',
    'Prevents outdated requests from overwriting newer data',
  ],
  '1.1.1': [
    'Improved automatic session renewal',
    'More reliable handling of simultaneous API requests',
    'Improved logout and session cleanup',
    'Fish Khata branding',
  ],
  '1.1.0': [
    'Home shows the next step for the day',
    'Purchase and hotel sale: pick many fish, enter kg and rate',
    'Entries save in the background with a popup',
    'End of day on one screen',
    'Full day sheet with tables in History',
    'Payment done screen',
    'Edit and delete entries',
    'Update notice',
  ],
};
