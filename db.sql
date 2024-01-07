create or replace table users
(
    username     varchar(255)  not null,
    userId       int auto_increment
        primary key,
    sessionToken varchar(255)  null,
    password     varchar(255)  not null,
    score        int default 0 not null
);

create or replace table gameRooms
(
    roomName    varchar(255) not null
        primary key,
    roomCreator int          not null,
    player_b    int          null,
    player_c    int          null,
    player_d    int          null,
    constraint gameRooms_users_userId_fk
        foreign key (roomCreator) references users (userId),
    constraint gameRooms_users_userId_fk_2
        foreign key (player_b) references users (userId),
    constraint gameRooms_users_userId_fk_3
        foreign key (player_c) references users (userId),
    constraint gameRooms_users_userId_fk_4
        foreign key (player_d) references users (userId)
);

create or replace table player_pieces
(
    pieceId  int,
    playerId int not null,
    piece1   int null,
    piece2   int null,
    piece3   int null,
    piece4   int null,
    constraint player_pieces_users_userId_fk
        foreign key (playerId) references users (userId)
);

create or replace table gameBoard
(
    gameId                  int auto_increment
        primary key,
    room                    varchar(255)                      not null,
    player_a_pieces         int                               not null,
    player_b_pieces         int                               null,
    player_c_pieces         int                               null,
    player_d_pieces         int                               null,
    dice                    int                               null,
    playerTurn              int                               not null,
    gameStatus              varchar(255) default 'notStarted' null,
    lastPlayerRolledTheDice int                               null,
    constraint gameBoard_gameRooms_roomName_fk
        foreign key (room) references gameRooms (roomName),
    constraint gameBoard_player_pieces_pieceId_fk
        foreign key (player_a_pieces) references player_pieces (pieceId),
    constraint gameBoard_player_pieces_pieceId_fk_2
        foreign key (player_b_pieces) references player_pieces (pieceId),
    constraint gameBoard_player_pieces_pieceId_fk_3
        foreign key (player_c_pieces) references player_pieces (pieceId),
    constraint gameBoard_player_pieces_pieceId_fk_4
        foreign key (player_d_pieces) references player_pieces (pieceId),
    constraint gameBoard_player_pieces_playerId_fk
        foreign key (playerTurn) references player_pieces (playerId),
    constraint gameBoard_player_pieces_playerId_fk_2
        foreign key (lastPlayerRolledTheDice) references player_pieces (playerId)
);

create or replace index player_pieces_gameBoard_gameId_fk
    on player_pieces (pieceId);

alter table player_pieces
    modify pieceId int auto_increment;

create or replace
    definer = kastik@localhost function createRoom(sessionToken_param varchar(255), roomName_param varchar(255)) returns tinyint(1)
begin
    declare userId_val varchar(255);

    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where users.sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;


    if exists(select * from gameRooms where roomName= roomName_param) then
        signal sqlstate '45000' set message_text = 'Room name already exists';
    else
        insert into gameRooms(roomName,roomCreator) value (roomName,userId_val);
        return true;
    end if;
end;

create or replace
    definer = kastik@localhost function createUser(username_param varchar(255), password_param varchar(255)) returns tinyint(1)
begin
    if exists(select * from users where username= username_param)then
        signal sqlstate '45000' set message_text = 'Username already exists';
    else
        insert into users(username,password,sessionToken) values (username_param,password_param,LEFT(UUID(), 8));
        return true;
    end if;
end;

create or replace
    definer = kastik@localhost function getGameState(sessionToken_param varchar(255)) returns longtext
begin
    declare userId_val int;
    declare currentPlayer_val int;
    declare gameRoomName_val varchar(255);
    declare gameStatus_val varchar(255);
    declare playerPieces_val json;

    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;

    -- Check if there is a currently running game for the user
    select roomName, playerTurn, gameStatus into gameRoomName_val, currentPlayer_val, gameStatus_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    if gameRoomName_val is null then
        -- No running game for the user
        signal sqlstate '45000' set message_text = 'You are not in a game that\'s running';
    end if;

    -- Retrieve player pieces for the current game
    select json_object(
                   'player_a_pieces', json_object(
                    'piece1', piece1,
                    'piece2', piece2,
                    'piece3', piece3,
                    'piece4', piece4
                                      )
           ) into playerPieces_val
    from player_pieces
             join gameBoard on playerId = player_a_pieces
             join gameRooms on room = roomName
    where roomName = gameRoomName_val;


    -- Add player_b_pieces, player_c_pieces, and player_d_pieces if available
    if exists(select 1 from gameRooms where roomName = gameRoomName_val and player_b is not null) then
        select json_set(playerPieces_val, '$.player_b_pieces', json_object(
                'piece1', piece1,
                'piece2', piece2,
                'piece3', piece3,
                'piece4', piece4
                                                               ))
        into playerPieces_val
        from player_pieces
                 join gameBoard on playerId = player_b_pieces
        where room = gameRoomName_val;
    end if;

    if exists(select 1 from gameRooms where roomName = gameRoomName_val and player_c is not null) then
        select json_set(playerPieces_val, '$.player_c_pieces', json_object(
                'piece1', piece1,
                'piece2', piece2,
                'piece3', piece3,
                'piece4', piece4
                                                               ))
        into playerPieces_val
        from player_pieces
                 join gameBoard on playerId = player_c_pieces
        where room = gameRoomName_val;
    end if;

    if exists(select 1 from gameRooms where roomName = gameRoomName_val and player_d is not null) then
        select json_set(playerPieces_val, '$.player_d_pieces', json_object(
                'piece1', piece1,
                'piece2', piece2,
                'piece3', piece3,
                'piece4', piece4
                                                               ))
        into playerPieces_val
        from player_pieces
                 join gameBoard on playerId = player_d_pieces
        where room = gameRoomName_val;
    end if;

    -- Create the final JSON object with game state information
    return json_object(
            'currentPlayer', currentPlayer_val,
            'gameRoomName', gameRoomName_val,
            'gameStatus', gameStatus_val,
            'playerPieces', playerPieces_val
           );
end;

create or replace
    definer = kastik@localhost function initializeGame(sessionToken_param varchar(255)) returns tinyint(1)
begin
    declare userId_val int;
    declare roomCreator_val int;
    declare roomName_val varchar(255);
    declare gameId_val int;
    declare player_b_val int;
    declare player_c_val int;
    declare player_d_val int;
    declare playerNum_val int;


    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;

    -- Get the room creator's userId, the roomName and gameId
    select roomCreator, roomName, gameId into roomCreator_val, roomName_val,gameId_val
    from gameRooms join gameBoard on roomName = room
    where roomCreator = userId_val and gameStatus not in ('player_a_won', 'player_b_won', 'player_c_won', 'player_d_won', 'running');

    -- Check if the user is the room creator
    if userId_val != roomCreator_val then
        -- User is not the room creator, cannot initialize the game
        signal sqlstate '45000' set message_text = 'You are not the room owner';
    end if;



    -- Get the other players userIds
    select player_b, player_c, player_d
    into player_b_val, player_c_val, player_d_val
    from gameRooms
    where roomName_val = roomName;


    -- Make sure at least 1 player is not null
    select count(*) into playerNum_val
    from gameRooms
    where roomName_val = roomName
      and (player_b is not null or player_c is not null or player_d is not null);


    if playerNum_val < 1 then
        -- Not enough players to initialize the game
        signal sqlstate '45000' set message_text = 'At least 1 other player needs to join';
    end if;

    -- Insert initial data into player_pieces table for the new players
    insert into player_pieces(playerId) values (roomCreator_val);


    if (player_b_val is not null) then
        insert into player_pieces (playerId) values (player_b_val);
    end if;

    if (player_c_val is not null) then
        insert into player_pieces(playerId) values (player_c_val);
    end if;

    if (player_d_val is not null ) then
        insert into player_pieces (playerId) values (player_d_val);
    end if;

    update gameBoard set gameBoard.gameStatus='running' where gameBoard.gameId=gameId_val;

    return true;

end;

create or replace
    definer = kastik@localhost function joinRoom(sessionToken_param varchar(255), roomName_param varchar(255)) returns tinyint(1)
begin
    declare userId_val int;
    declare player_b_val int;
    declare player_c_val int;
    declare player_d_val int;
    declare playerNum_val int;


    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;


    -- Get the other four players ids
    select player_b, player_c, player_d
    into player_b_val, player_c_val, player_d_val
    from gameRooms
    where roomName_param = roomName;


    if not exists(select roomName from gameRooms where roomName=roomName_param) then
        signal sqlstate '45000' set message_text = 'Room does not exist';
    end if;


    -- Make sure at least 1 spot is free
    select count(*) into playerNum_val
    from gameRooms
    where roomName_param = roomName
      and (player_b is null or player_c is null or player_d is null);

    if playerNum_val < 1 then
        -- Room is full
        signal sqlstate '45000' set message_text = 'Room is full';
    end if;




    -- Make sure game is not already running or finished
    if exists(select * from gameBoard join gameRooms on room = roomName
              where roomName=roomName_param and gameStatus in ('player_a_won', 'player_b_won', 'player_c_won', 'player_d_won', 'running')) then
        -- The game is already running
        signal sqlstate '45000' set message_text = 'The game is already running';
    end if;



    if(player_b_val is null ) then
        update gameRooms set player_b=userId_val where roomName=roomName_param;
        return true;
    elseif(player_c_val is null) then
        update gameRooms set player_c=userId_val where roomName=roomName_param;
        return true;
    elseif(player_d_val is null) then
        update gameRooms set player_d=userId_val where roomName=roomName_param;
        return true;
    else
        signal sqlstate '45000' set message_text = 'Atomicity problem';
    end if;

end;

create or replace
    definer = kastik@localhost procedure movePiece(IN sessionToken_param varchar(255), IN pieceSelection_param int)
begin
    declare piece_column_val varchar(255);
    declare isGameRunning_val int;
    declare isPlayersTurn_val int;
    declare userId_val int;
    declare moveBlocks_val int;

    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;


    -- Determine which piece column to update based on piece_number
    case pieceSelection_param
        when 1 then set piece_column_val = 'piece1';
        when 2 then set piece_column_val = 'piece2';
        when 3 then set piece_column_val = 'piece3';
        when 4 then set piece_column_val = 'piece4';
        else
            -- Invalid piece_number
            signal sqlstate '45000' set message_text = 'Invalid piece_number';
        end case;

    -- Check if there is a currently running game for the user
    select count(*) into isGameRunning_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    if isGameRunning_val = 0 then
        -- No running game for the user
        signal sqlstate '45000' set message_text = 'No running game for the user';
    end if;

    -- Check if it is the user's turn
    select count(*) into isPlayersTurn_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and playerTurn = userId_val;

    if isPlayersTurn_val = 0 then
        -- Not their turn
        signal sqlstate '45000' set message_text = 'Not your turn yet';
    end if;

    select dice
    from gameBoard
             join gameRooms on roomName = room where gameStatus like 'running' into moveBlocks_val;

    if moveBlocks_val < 1 or moveBlocks_val > 6 then
        signal sqlstate '45000' set message_text = 'Illegal move';
    end if;

    -- Update the player_turn column in the gameBoard table for the user's current game
    update gameBoard
    set playerTurn = case
                         when player_a_pieces = userId_val then coalesce(player_b_pieces, player_c_pieces, player_d_pieces, player_a_pieces)
                         when player_b_pieces = userId_val then coalesce(player_c_pieces, player_d_pieces, player_a_pieces, player_b_pieces)
                         when player_c_pieces = userId_val then coalesce(player_d_pieces, player_a_pieces, player_b_pieces, player_c_pieces)
                         when player_d_pieces = userId_val then coalesce(player_a_pieces, player_b_pieces, player_c_pieces, player_d_pieces)
        end,
        dice = moveBlocks_val
    where room in (select roomName from gameRooms where roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val)
      and gameStatus = 'running';

    -- Prepare and execute the dynamic SQL
    set @sql = concat('update player_pieces join gameBoard on playerId = ', userId_val, ' set ', piece_column_val, ' =', piece_column_val, ' + ? where player_a_pieces = pieceId or player_b_pieces = pieceId or player_c_pieces = pieceId or player_d_pieces = pieceId and gameStatus = ''running''');
    set @move_by_blocks = moveBlocks_val;
    prepare stmt from @sql;
    execute stmt using @move_by_blocks;
    deallocate prepare stmt;
end;

create or replace
    definer = kastik@localhost function updateDiceValue(sessionToken_param varchar(255), newValue_param int) returns tinyint(1)
begin
    declare userId_val int;
    declare currentPlayer_val int;
    declare isGameRunning_val int;
    declare diceTurn_val int;


    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;

    -- Check if there is a currently running game for the user
    select count(*) into isGameRunning_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    if isGameRunning_val = 0 then
        -- No running game for the user
        signal sqlstate '45000' set message_text = 'You are not currently in any running game';
    end if;

    -- Get the current player's turn
    select playerTurn into currentPlayer_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    -- Check if it's the player's turn
    if currentPlayer_val != userId_val then
        -- It's not the player's turn
        signal sqlstate '45000' set message_text = 'It is not your turn yet';
    end if;


    -- Check if player rolled the dice for the first time
    select lastPlayerRolledTheDice into diceTurn_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    if diceTurn_val = userId_val then
        -- Player tried to roll it again
        signal sqlstate '45000' set message_text = 'You can not roll multiple times';
    end if;


    -- Set the lastPlayerValue to the current player
    update gameBoard set lastPlayerRolledTheDice = userId_val
    where room in (select roomName from gameRooms where roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val)
      and gameStatus = 'running';


    -- Update the dice
    update gameBoard
    set dice = newValue_param
    where room in (select roomName from gameRooms where roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val)
      and gameStatus = 'running';

    return true;
end;

