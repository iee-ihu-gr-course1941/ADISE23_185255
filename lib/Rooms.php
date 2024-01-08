<?php
require_once "DatabaseConnection.php";
function joinRoom($roomName): void{
     global $conn;
     $sql = 'select joinRoom(?,?);';
     $st = $conn->prepare($sql);
     $st->bind_param('ss',$_SESSION['TOKEN'],$roomName);
     $st->execute();
     $res = $st->get_result();
     $r = $res->fetch_assoc();
     if ($r["joinRoom(?,?)"]){
         echo json_encode('Success Joining');
     }else{
         echo json_encode('Error');
     }
}

function getRooms(): void{
    if (!isset($_SESSION['TOKEN'])){
        http_response_code(401);
        echo json_encode('You need to login first');
    }else {
        global $conn;
        $sql = 'SELECT roomName FROM gameRooms;';
        $st = $conn->prepare($sql);
        $st->execute();
        $res = $st->get_result();
        $r = $res->fetch_all();
        $data = [];
        foreach ($r as $row) {
            $data[] = $row[0];
        }
        echo json_encode($data, JSON_PRETTY_PRINT);
    }
}
function createRoom($roomName): void{
    global $conn;
    $sql = 'select createRoom(?,?)';
    $st = $conn->prepare($sql);
    $st->bind_param('ss', $_SESSION['TOKEN'], $roomName);
    $st->execute();
    $res = $st->get_result();
    $r = $res->fetch_assoc();
    if ($r['createRoom(?,?)']) {
        echo json_encode('Successful creation of room');
    } else {
        echo json_encode('Room already exists');
    }
}