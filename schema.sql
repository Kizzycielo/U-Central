-- ============================================================
-- U-Central Database Schema
-- Run this once to set up all tables
-- ============================================================

-- SESSION TABLE
-- Required by connect-pg-simple (the library that saves login
-- sessions to the database instead of server memory).
-- Each row = one logged-in user's session data.
CREATE TABLE IF NOT EXISTS "session" (
    "sid" varchar NOT NULL COLLATE "default",
    "sess" json NOT NULL,
    "expire" timestamp(6) NOT NULL,
    CONSTRAINT "session_pkey" PRIMARY KEY ("sid")
) WITH (OIDS=FALSE);

CREATE INDEX IF NOT EXISTS "IDX_session_expire"
    ON "session" ("expire");


-- USERS TABLE
-- Stores every account created through the signup page.
-- id: auto-incrementing unique number for each user
-- full_name: what they typed in "Full name" field
-- email: their login email (must be unique)
-- password: bcrypt-hashed password (never stored as plain text)
-- role: either 'student' or 'faculty'
-- id_photo_path: file path to their uploaded ID photo
-- bio: optional profile bio text
-- department_id: for faculty, which office they're assigned to
-- created_at: when they signed up
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password TEXT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'student',
    id_photo_path TEXT,
    bio TEXT DEFAULT '',
    department_id INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);


-- DEPARTMENTS TABLE (Offices)
-- Each row is one campus office (e.g. Registrar, Library, OSAS).
-- Faculty can be assigned to one office via users.department_id.
-- Only faculty can create offices.
CREATE TABLE IF NOT EXISTS departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT DEFAULT '',
    location VARCHAR(150) DEFAULT 'Main Building',
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Link users.department_id to departments.id
-- This is done after both tables exist to avoid circular reference
ALTER TABLE users
    ADD CONSTRAINT fk_users_department
    FOREIGN KEY (department_id)
    REFERENCES departments(id)
    ON DELETE SET NULL;


-- POSTS TABLE
-- Stores every post in the system regardless of where it appears.
-- post_type distinguishes where the post lives:
--   'home'    = Main Feed
--   'freedom' = Freedom Wall
--   'office'  = inside a specific office page
-- post_subtype is the category badge:
--   'announcement', 'event', 'update', 'maintenance'
-- department_id: only filled for office posts
-- title: optional, mainly used in Freedom Wall posts
-- body: the actual post content (HTML allowed from Quill editor)
-- flair: optional label tag on Freedom Wall posts
-- likes: running count of likes (updated when someone likes/unlikes)
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    department_id INTEGER REFERENCES departments(id) ON DELETE CASCADE,
    post_type VARCHAR(20) NOT NULL,
    post_subtype VARCHAR(30) DEFAULT 'announcement',
    title VARCHAR(250),
    body TEXT NOT NULL,
    flair VARCHAR(50),
    likes INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);


-- POST LIKES TABLE
-- Tracks which user liked which post.
-- Prevents the same user from liking a post twice.
-- When a user likes: insert a row here + increment posts.likes
-- When a user unlikes: delete that row + decrement posts.likes
-- PRIMARY KEY (user_id, post_id) = each pair can only exist once
CREATE TABLE IF NOT EXISTS post_likes (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, post_id)
);


-- COMMENTS TABLE
-- Stores comments on any post.
-- parent_id: if this comment is a reply to another comment,
--            parent_id holds the id of that parent comment.
--            If parent_id IS NULL, it's a top-level comment.
-- This creates a "tree" structure for threaded replies.
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id INTEGER REFERENCES comments(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);


-- POLLS TABLE
-- The poll question itself. Each poll belongs to one user.
CREATE TABLE IF NOT EXISTS polls (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);


-- POLL OPTIONS TABLE
-- Each poll can have multiple options (minimum 2).
-- votes: running count of how many people picked this option.
CREATE TABLE IF NOT EXISTS poll_options (
    id SERIAL PRIMARY KEY,
    poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_text VARCHAR(200) NOT NULL,
    votes INTEGER DEFAULT 0
);


-- POLL VOTES TABLE
-- Tracks which user voted on which poll and which option they chose.
-- PRIMARY KEY (user_id, poll_id) = each user can only vote once per poll.
CREATE TABLE IF NOT EXISTS poll_votes (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    poll_id INTEGER NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id INTEGER NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, poll_id)
);


-- EVENTS TABLE
-- Personal calendar events added by logged-in users.
-- Each user only sees their own events (filtered by user_id).
-- event_date is stored as text so users can type things like
-- "May 30, 2pm" or "June 1 - Finals Week" freely.
CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    event_date VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- VERIFICATION
-- After running this file, you should see all these tables:
-- session, users, departments, posts, post_likes,
-- comments, polls, poll_options, poll_votes, events
-- Run: \dt   inside psql to list all tables
-- ============================================================