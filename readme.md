# QueueLess

QueueLess is a smart queue management system that allows users to book digital tokens instead of waiting in physical lines. Organizations can manage queues, service timings, and customer flow efficiently, while users can monitor live queue status, receive notifications, and visit only when their turn is near.

The system consists of a **Flutter** mobile application and a **Spring Boot** backend with REST APIs.

---

# Tech Stack

## Frontend

* Flutter
* Dart
* Google Maps
* QR Code Scanner
* Firebase Cloud Messaging (FCM)

## Backend

* Spring Boot
* Spring Security
* Spring Data JPA
* Spring Mail
* JWT Authentication
* REST APIs

## Database

* MySQL

---

# User Roles

## 1. User

Customers who book queue tokens.

## 2. Organization

Businesses, hospitals, banks, government offices, salons, etc., that manage customer queues.

---

# Main Features

## Authentication

### User

* Sign Up
* Login
* Forgot Password
* Email Verification
* JWT Authentication

### Organization

* Sign Up
* Login
* Forgot Password
* Email Verification
* JWT Authentication

---

# Organization Features

* Create organization profile
* Edit organization information
* Add organization logo
* Add organization address
* Select location using Google Maps
* Set opening time
* Set closing time
* Enable or disable token generation
* View today's queue
* Generate queue tokens
* Complete current customer's service
* Automatically notify next customer
* View queue history
* View completed tokens
* View skipped tokens
* Configure late arrival swap limit
* Support multiple organizations in one application

---

# User Features

* Register account
* Login
* Verify email
* Reset password
* Browse all organizations
* Search organizations
* View organization details
* View opening time
* View closing time
* View live queue status
* View remaining tokens
* View estimated waiting position
* Book digital token
* Get token by scanning QR Code at organization office
* Receive live queue updates
* Configure notification preference
* View token history
* Cancel token (if allowed)
* Navigate to organization using Google Maps

---

# Queue Management

Each organization manages its own independent queue.

Users can obtain tokens by:

* Selecting an organization from the application
* Scanning the organization's QR Code

Each token contains:

* Token Number
* Queue Position
* Status
* Booking Time
* Estimated Waiting Time

---

# Queue Status

Token can have the following status:

* Waiting
* Called
* In Service
* Completed
* Skipped
* Cancelled

---

# Smart Notification System

Users receive push notifications when:

* Token is booked
* Queue position changes
* Service is about to begin
* Token is called
* Organization closes
* Queue is cancelled

Default notification:

* Notify when only **2 people** remain before the user's turn.

User can customize notification to:

* 1 person ahead
* 2 people ahead (Default)
* 3 people ahead

---

# QR Code Token System

Every organization has its own QR Code.

When scanned:

* User is redirected to that organization.
* Token is generated automatically.
* User joins the queue instantly.

---

# Service Completion Workflow

1. Employee serves current customer.
2. Employee clicks **Complete Service**.
3. Current token becomes Completed.
4. Next waiting token becomes Active.
5. Notification is sent to the next customer.

---

# Late Arrival Swap System

If the called customer does not arrive:

* Organization can mark the customer as Late.
* The token is swapped with the next customer(s).

Example:

Current Queue

1 → Called (Late)

2 → Waiting

3 → Waiting

If swap limit is **1**

Queue becomes

2 → Called

1 → Waiting

3 → Waiting

If swap limit is **2**

Queue becomes

2 → Called

3 → Waiting

1 → Waiting

The maximum swap limit is configurable by each organization.

---

# Organization History

Organization can view:

* Today's queue
* Previous queues
* Completed services
* Cancelled tokens
* Skipped customers
* Daily statistics
* Monthly statistics

---

# User History

User can view:

* Previous bookings
* Completed tokens
* Cancelled bookings
* Missed tokens
* Organization visited
* Booking date
* Token details

---

# Google Maps Integration

Organization can:

* Select address from Google Maps
* Save latitude and longitude
* Update location anytime

User can:

* View organization location
* Open navigation in Google Maps
* View distance to organization

---

# Multi-Organization Support

The application supports one or more organizations.

Each organization has:

* Independent queue
* Independent opening hours
* Independent QR Code
* Independent employees
* Independent token numbering
* Independent queue history

---

# Functional Requirements

### Authentication

* User Registration
* User Login
* Organization Registration
* Organization Login
* Email Verification
* Forgot Password
* JWT Authentication

### Organization

* Create organization
* Update profile
* Set opening and closing time
* Manage queue
* Generate tokens
* Complete services
* Configure late swap settings
* View reports
* Manage location

### User

* Browse organizations
* Book tokens
* Scan QR Code
* Receive notifications
* View queue
* View history
* View organization location
* Customize notification preference

---

# Non-Functional Requirements

* Secure JWT Authentication
* Email Verification
* Fast API Response
* Responsive Flutter UI
* Real-time Queue Updates
* Scalable Spring Boot Architecture
* MySQL Database
* RESTful APIs
* Cross-platform Mobile Application
* Reliable Push Notifications

---

# Database Entities

## User

* id
* name
* email
* password
* phone
* emailVerified
* notificationPreference
* createdAt

## Organization

* id
* organizationName
* email
* password
* phone
* address
* latitude
* longitude
* openingTime
* closingTime
* qrCode
* swapLimit
* emailVerified
* createdAt

---

# Future Enhancements

* Employee Management
* Admin Dashboard
* Analytics and Reports
* SMS Notifications
* WhatsApp Notifications
* Appointment Scheduling
* Online Payments
* AI-based Waiting Time Prediction
* Multi-Branch Organizations
* Dark Mode
* Multi-Language Support

---

# Project Objective

QueueLess aims to eliminate long physical queues by allowing users to obtain digital tokens, receive smart notifications, monitor live queue status, and arrive only when their service is near. Organizations can efficiently manage customer flow, reduce overcrowding, and provide a faster and more organized service experience.
