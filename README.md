# Planmate Mobile App

Planmate is a cross-platform social calendar and event management ecosystem. It allows users to manage their personal schedules, seamlessly sync with native device calendars, connect with friends, and coordinate shared events—all backed by a secure cloud infrastructure.

## Key Features

* **Social Scheduling:** Send friend requests, accept invitations, and view your friends' calendars to find the perfect time to meet.
* **Native Calendar Sync:** Automatically pulls in events from native device calendars (Google, Apple, Samsung) alongside Planmate-specific events.
* **Smart Event Management:** Create, edit, and delete events with a beautiful, intuitive UI. Invite friends to events directly from the app.
* **Authentication:** Secure user registration and login using Spring Security and JWTs.

## Tech Stack

**Mobile Frontend**
* **Framework:** Flutter (Dart)

**Backend API**
* **Framework:** Spring Boot (Java)
* **Database:** PostgreSQL

**Infrastructure & DevOps**
* **Hosting:** Google Cloud Platform (GCP) Debian VM
* **Containerization:** Docker & Docker Compose (with persistent named volumes)
* **Traffic Management:** Nginx Reverse Proxy
* **Security:** Let's Encrypt SSL with automated Certbot renewal hooks
* **CI/CD:** GitHub Actions

---

## 🚀 Getting Started (Local Development)

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install)
* [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for local database)
* Java 17+ & Maven/Gradle

### 1. Backend Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/ilboyadjiev/planmate.git
   ```

2. Start the local PostgreSQL database using Docker:
    ```bash
    docker-compose -f docker-compose.local.yml up -d
    ```

### 2. Mobile setup ###
1. Clone the repository:
   ```bash
   git clone https://github.com/ilboyadjiev/planmate-mobile.git
   cd planmate-mobile
   ```

2. Install dependencies
    ```bash
    flutter pub get
    ```

3. Run the app. By default, it connects to the production server. To run against your local backend, use the --dart-define flag:
    ```bash
    # For iOS Simulator:
    flutter run --dart-define=BASE_URL=http://localhost:8080

    # For Android Emulator:
    flutter run --dart-define=BASE_URL=http://10.0.2.2:8080
    ```

### Production Architecture ###
Planmate is deployed on a Google Cloud Platform VM.

Nginx acts as the API Gateway, handling SSL termination (Port 443) and automatically redirecting insecure HTTP traffic.

API requests (/api/v1/*) are proxied to the Spring Boot container.

Data is persisted in a PostgreSQL container utilizing Docker named volumes to ensure data safety across deployments.

GitHub Actions handles continuous deployment, pulling new Docker images and recreating containers with zero noticeable downtime.

### License ###
This project is licensed under the MIT License.