<?php



header("Content-type: application/json; charset=UTF-8");
require_once "lib/ErrorHandler.php";
set_exception_handler("ErrorHandler::handleException");
session_start();

require_once "lib/Users.php";
require_once "lib/Rooms.php";
require_once "lib/Ludo.php";


$requestURI = explode("/",$_SERVER["REQUEST_URI"]);
$httpMethod = $_SERVER['REQUEST_METHOD'];

switch ($requestURI[1]) {
    case 'user':{
        if($httpMethod=="GET"){
            userAuth($requestURI[2],$requestURI[3]);
            break;
        }elseif($httpMethod=="POST"){
            createUser($requestURI[2],$requestURI[3]);
            break;
        }elseif($httpMethod=='PUT'){
            showUserInfo();
            break;
        }else{
            http_response_code(404);
            break;
        }

    }
    case 'game':
    {
        if ($httpMethod == "GET") {
            showScoreBoard();
            break;
        } elseif ($httpMethod == "POST") {
            switch ($requestURI[2]) {
                case 'gameState':
                {
                    getGameState();
                    break;
                }
                case 'dice':
                {
                    rollDice();
                    break;
                }
                case 'move':
                {
                    movePiece($requestURI[3]);
                    break;
                }
                case 'init':
                {
                    initGame();
                    break;
                }
                default:
                {
                    http_response_code(404);
                    echo json_encode("Not found");
                    break;
                }
            }
            break;
        } else {
            http_response_code(404);
            //TODO MAYBE SOMETHING ELSE Like DELETE OR keep 404
            break;
        }
    }
    case "rooms": {
        if($httpMethod=="POST"){
            joinRoom($requestURI[2]);
            break;
        }elseif($httpMethod=="GET"){
            getRooms();
            break;
        }
        elseif($httpMethod=="PUT"){
            createRoom($requestURI[2]);
            break;
        }else{
            http_response_code(404);
            json_encode('The page was not found');
            break;
        }
    }
    default:{
        echo json_encode("DEFAULT");
        http_response_code(404);
        break;
    }
}