# Fintrack

Fintrack is a responsive Flutter web application for personal finance management.

## Implemented features

- Responsive dashboard with balance, income, expenses, savings rate and recent activity
- Transaction create, edit, delete, search and income/expense filtering
- Category budgets with current-month utilization
- Savings goals with contributions and deadlines
- Spending analytics and category breakdown
- INR, USD, EUR, GBP, AED, CAD and AUD transaction entry with a saved manual conversion-rate snapshot
- Light and dark themes
- Guest workspace with browser persistence and sample data
- Firebase email/password registration and sign-in
- Per-user Cloud Firestore workspace persistence for authenticated accounts
- GitHub Actions deployment workflow for GitHub Pages

## Requirements

- Flutter stable with web support
- Google Chrome or Microsoft Edge
- A Firebase project for account sign-in and cloud synchronization (guest mode works without Firebase)

## Run in guest mode

```powershell
cd C:\Users\hp\fintrack
flutter pub get
flutter run -d chrome
```

If Firebase is not configured, the app opens the account screen with a clear Firebase setup notice and a **Continue as guest** option. Guest records remain in that browser only.

## Configure Firebase

1. Create a project in the Firebase Console.
2. Add a **Web app** to the Firebase project.
3. In **Authentication → Sign-in method**, enable **Email/Password**.
4. Create a **Cloud Firestore** database.
5. Open Firestore **Rules** and publish the contents of `firestore.rules`.
6. Copy the web app configuration values from Firebase project settings.
7. Run the app with the values below (replace each placeholder with the corresponding value):

```powershell
flutter run -d chrome `
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_APP_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID `
  --dart-define=FIREBASE_AUTH_DOMAIN=YOUR_PROJECT_ID.firebaseapp.com `
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_PROJECT_ID.firebasestorage.app
```

The same configuration values must be supplied to the GitHub Actions workflow as repository secrets named `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_AUTH_DOMAIN`, and `FIREBASE_STORAGE_BUCKET`. Firebase web configuration is designed to be present in client applications; Firestore security rules and Authentication protect user data. Never put a Firebase Admin SDK service-account key in this Flutter app or repository.

### Firestore data model

Authenticated workspace data is stored at:

`users/{Firebase Auth UID}/fintrack/workspace`

Each account can read and write only its own workspace under the included security rules. Guest mode does not write to Firestore.

## Build for GitHub Pages

For a repository named `fintrack`:

```powershell
flutter build web --release --base-href "/fintrack/"
```

Push the project to the `main` branch of a GitHub repository named `fintrack`. In **Settings → Pages**, select **GitHub Actions** as the deployment source. The included workflow builds and deploys the web app. Add the six Firebase repository secrets listed above to enable Firebase on the deployed site. Without them, guest mode remains available.

## Important financial-data notes

- This is a personal finance tracker, not a bank connection or payment processor.
- Exchange rates are manually entered and saved with each transaction; they are not live market rates.
- Guest data is browser-local. Authenticated user data is stored in that user's Firestore workspace.
- Do not enter bank passwords, card PINs, or other payment credentials.

## Suggested academic demonstration

1. Register a new account and sign in.
2. Add income and expense transactions.
3. Edit, delete, search and filter transactions.
4. Set a monthly category budget and demonstrate its progress.
5. Create a savings goal and add a contribution.
6. Demonstrate analytics and the savings rate.
7. Change base currency and theme.
8. Refresh the page and sign in again to demonstrate cloud persistence.
9. Sign out and use guest mode to demonstrate separation from the account workspace.

