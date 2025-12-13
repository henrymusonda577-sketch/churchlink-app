# Firestore Composite Indexes Setup

This document provides instructions for creating the required composite indexes in Firestore to resolve the "The query requires an index" errors.

## Why Composite Indexes Are Needed

Firestore requires composite indexes when queries use multiple `where` clauses combined with `orderBy`. The error messages will include a direct link to create the index in the Firebase Console.

## Required Indexes

Based on the queries in your codebase, you need to create the following composite indexes:

### BibleService Indexes

#### Bookmarks Collection
```
Collection: bookmarks
Fields:
- userId (Ascending)
- timestamp (Descending)
```

Query: `where('userId', isEqualTo: user.uid).orderBy('timestamp', descending: true)`

#### Notes Collection
```
Collection: notes
Fields:
- userId (Ascending)
- timestamp (Descending)
```

Query: `where('userId', isEqualTo: user.uid).orderBy('timestamp', descending: true)`

#### Highlights Collection
```
Collection: highlights
Fields:
- userId (Ascending)
- timestamp (Descending)
```

Query: `where('userId', isEqualTo: user.uid).orderBy('timestamp', descending: true)`

#### Recent Verses Collection
```
Collection: recent_verses
Fields:
- userId (Ascending)
- timestamp (Descending)
```

Query: `where('userId', isEqualTo: user.uid).orderBy('timestamp', descending: true)`

### Additional Indexes (if needed)

#### Notes Deletion/Update Queries
```
Collection: notes
Fields:
- userId (Ascending)
- book (Ascending)
- chapter (Ascending)
- verse (Ascending)
```

Query: `where('userId', isEqualTo: user.uid).where('book', isEqualTo: book).where('chapter', isEqualTo: chapter).where('verse', isEqualTo: verse)`

#### Bookmarks Deletion Query
```
Collection: bookmarks
Fields:
- userId (Ascending)
- book (Ascending)
- chapter (Ascending)
- verse (Ascending)
```

Query: `where('userId', isEqualTo: user.uid).where('book', isEqualTo: book).where('chapter', isEqualTo: chapter).where('verse', isEqualTo: verse)`

#### Highlights Deletion/Get Queries
```
Collection: highlights
Fields:
- userId (Ascending)
- book (Ascending)
- chapter (Ascending)
- verse (Ascending)
```

Query: `where('userId', isEqualTo: user.uid).where('book', isEqualTo: book).where('chapter', isEqualTo: chapter).where('verse', isEqualTo: verse)`

## How to Create Indexes

### Method 1: Using Firebase Console (Recommended)

1. Go to your Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Go to Firestore Database → Indexes
4. Click "Create Index"
5. Fill in the collection ID and fields as specified above
6. Click "Create"

### Method 2: Using Error Links

When you encounter a Firestore error in your app, the error message will include a direct link to create the required index:

1. Run your app and trigger the query that causes the error
2. Check the console/logs for the error message
3. The error will contain a link like: `https://console.firebase.google.com/...`
4. Click the link to automatically create the index

### Method 3: Using Firebase CLI

If you have Firebase CLI installed:

```bash
firebase firestore:indexes
```

This will show existing indexes and allow you to deploy new ones via configuration files.

## Testing

After creating the indexes:

1. Run your app
2. Test the features that were failing:
   - Bible bookmarks
   - Bible notes
   - Bible highlights
   - Recent verses
3. Verify that the Firestore errors are resolved

## Notes

- Index creation can take a few minutes to several hours depending on the size of your database
- You can monitor the status in the Firebase Console under Indexes
- Make sure to test thoroughly after indexes are built
- If you have a large dataset, consider the cost implications of additional indexes
