<?php
require_once "DatabaseConnection.php";



function userAuth($username,$password): void{
    global $conn;
    $sql = 'select * from users where username=? and password=?';
    $st = $conn->prepare($sql);
    $st->bind_param('ss', $username,$password);
    $st->execute();
    $res = $st->get_result();
    $r = $res->fetch_assoc();

    if (empty($r['sessionToken'])) {
        http_response_code(401);
        echo json_encode('Wrong credentials');
    }else{
        $_SESSION['TOKEN'] = $r["sessionToken"];
        http_response_code(200);
        echo json_encode('Successful Login');
    }

}

function createUser(string $username,string $password): void{
    global $conn;
    $sql = 'select createUser(?,?)';
    $st = $conn->prepare($sql);
    $st->bind_param("ss",$username,$password);
    $st->execute();
    $res = $st->get_result();
    $s = $res->fetch_assoc();
    if ($s['createUser(?,?)']){
        http_response_code(201);
        echo json_encode("SUCCESS");
    }else{
        http_response_code(400);
        echo json_encode("FAILURE");

    }
}


function showUserInfo(): void{
    global $conn;
    $sql = 'select getUserInfo(?)';
    $st = $conn->prepare($sql);
    $st->bind_param('s',$_SESSION['TOKEN']);
    $st->execute();
    $res= $st->get_result();
    $r = $res->fetch_assoc();
    print_r($r['getUserInfo(?)']);
}