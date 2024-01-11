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

switch ($requestURI[2]) {
    case 'user':{
        if($requestURI[3]=='auth'){
            userAuth($requestURI[4],$requestURI[5]);
            break;
        }elseif($requestURI[3]=="create"){
            createUser($requestURI[4],$requestURI[5]);
            break;
        }elseif($requestURI[3]=='info'){
            showUserInfo();
            break;
        }else{
            http_response_code(404);
            break;
        }

    }
    case 'game':
    {
        switch ($requestURI[3]) {
            case 'scores':{
                showScoreBoard();
                break;
            }
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
                movePiece($requestURI[4]);
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
                echo json_encode("Not found :(");
                break;
            }
        }
        break;
    }
    case "rooms": {
        if($requestURI[3]=='join'){
            joinRoom($requestURI[4]);
            break;
        }elseif($requestURI[3]=='info'){
            getRooms();
            break;
        }
        elseif($requestURI[3]=='create'){
            createRoom($requestURI[4]);
            break;
        }else{
            http_response_code(404);
            json_encode('The page was not found');
            break;
        }
    }
    default:{
        echo json_encode("sOmEtHiNg Is WrOnG");
	    http_response_code(404);
        break;
    }
}
