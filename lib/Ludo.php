<?php
require_once 'DatabaseConnection.php';

function rollDice(): void{
    $dice['roll'] = rand(1, 6);
    global $conn;
    $sql = 'select updateDiceValue(?, ?) as result';
    $st = $conn->prepare($sql);
    $st->bind_param('si', $_SESSION['TOKEN'], $dice['roll']);
    $st->execute();
    $res = $st->get_result();
    $r = $res->fetch_assoc();
    if ($r["result"]){
        echo json_encode($dice);
    }else{
        echo json_encode("It's not your turn yet");
        http_response_code(401);
    }
}
function initGame(): void {
    global $conn;
    $sql = 'select initializeGame(?)';
    $st = $conn->prepare($sql);
    $st->bind_param('s',$_SESSION['TOKEN']);
    $st->execute();
    $res= $st->get_result();

    $r = $res->fetch_assoc();
    if ($r['initializeGame(?)']){
        echo json_encode('Successful init');
    }else{
        echo json_encode('Error');
    }
}
function getGameState(): void{
    global $conn;
    $sql = 'select getGameState(?)';
    $st = $conn->prepare($sql);
    $st->bind_param('s',$_SESSION['TOKEN']);
    $st->execute();
    $res= $st->get_result();
    $r = $res->fetch_assoc();
    print_r($r['getGameState(?)']);

}

function movePiece(int $piece): void{
    global $conn;
    $sql = 'call movePiece(?,?);';
    $st = $conn->prepare($sql);
    $st->bind_param('si',$_SESSION['TOKEN'],$piece);
    if($st->execute()){
        echo json_encode('Move successful');
    }else{
        echo json_encode('Something went wrong' );
        http_response_code(401);
    }
}


function showScoreBoard():void{
    //Public method no need to sign in
    global $conn;
    $sql = 'select username,score from users;';
    $st = $conn->prepare($sql);
    $st->execute();
    $res = $st->get_result();
    $myArray = array();
    while($row = $res->fetch_assoc()) {
        $myArray[] = $row;
    }
    echo json_encode($myArray);
}
