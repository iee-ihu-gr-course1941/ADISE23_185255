# Ludo Game API

This is a simple PHP-based Web API for a Ludo game. It includes endpoints for user creation/authentication, game status management.



[Live demo] https://users.it.teithe.gr/~it185255/
## Getting Started

To use this API, you'll need a web server with PHP and a MariaDB database. Follow the steps below to set it up:

### Prerequisites

- PHP
- MariaDB

### Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/iee-ihu-gr-course1941/ADISE23_185255.git
    


2. Update `DatabaseConnection.php` with your MySQL credentials:

    ```php
    $servername = "localhost";
    $username = "your_username";
    $password = "your_password";
    $dbname = "your_database";
    ```

3. Make sure your web server is configured to read the .htaccess file in order to serve the API 

    ```bash
    RewriteEngine On
    RewriteRule . index.php
    ```
   
4. Use the API by making requests to the endpoints.

## API Endpoints

### User Management

#### 1. User Authentication

- **Endpoint:** `/user/auth/{parameter1}/{parameter2}`
- **Method:** `GET`
- **Parameters:** `username` and `password`
- **Description:** Authenticates a user. Returns a session token on successful login.

#### 2. User Registration

- **Endpoint:** `/user/create/{parameter1}/{parameter2}`
- **Method:** `GET`
- **Parameters:** `username` and `password`
- **Description:** Registers a new user.

#### 3. Get User Information

- **Endpoint:** `/user/info`
- **Method:** `GET`
- **Description:** Retrieves information about the authenticated user.

### Game Management

#### 1. Get Scoreboard

- **Endpoint:** `/game/score`
- **Method:** `GET`
- **Description:** Retrieves the current scoreboard.

#### 2. Game State

- **Endpoint:** `/game/gameState`
- **Method:** `GET`
- **Description:** Retrieves the current state of the game.

#### 3. Roll Dice

- **Endpoint:** `/game/dice`
- **Method:** `GET`
- **Description:** Rolls the dice for the current player if the game is still running.

#### 4. Move Piece

- **Endpoint:** `/game/move/{piece}`
- **Method:** `GET`
- **Parameters:** `piece` (piece ID)
- **Description:** Moves the specified game piece can take values 1-4.

#### 5. Initialize Game

- **Endpoint:** `/game/init`
- **Method:** `GET`
- **Description:** Initializes the game only if it is run by the room creator.

### Room Management

#### 1. Create Room

- **Endpoint:** `/rooms/create/{parameter}`
- **Method:** `GET`
- **Parameters:** `roomName`
- **Description:** Creates a new game room named parameter.

#### 2. Join Room

- **Endpoint:** `/rooms/join/{parameter}`
- **Method:** `GET`
- **Parameters:** `roomName`
- **Description:** Joins a game room named parameter.

#### 3. Get Rooms

- **Endpoint:** `/rooms/info`
- **Method:** `GET`
- **Description:** Retrieves a list of available game rooms.

## Error Handling

The API utilizes a custom error handler (`ErrorHandler`) to handle exceptions gracefully. In case of an error, the response has an error code, message, file, and line number.

## Database Connection

The `DatabaseConnection.php` file contains the database connection details. Update it with your MariaDB credentials.

```php
$servername = "localhost";
$username = "your_username";
$password = "your_password";
$dbname = "your_database";
```
