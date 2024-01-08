create table log
(
    t       datetime     null,
    comment varchar(255) null
);

create table users
(
    username     varchar(255)  not null,
    userId       int auto_increment
        primary key,
    sessionToken varchar(255)  null,
    password     varchar(255)  not null,
    score        int default 0 not null
);

create table gameRooms
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

create table player_pieces
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

create table gameBoard
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

create definer = kastik@localhost trigger checkIfWon
    after update
    on gameBoard
    for each row
BEGIN
    DECLARE gameId_val INT;
    DECLARE playerPieceA_val INT;
    DECLARE playerPieceB_val INT;
    DECLARE playerPieceC_val INT;
    DECLARE playerPieceD_val INT;
    declare won tinyint(1);



    -- Find the pieces for each player
    SELECT gb.player_a_pieces, gb.player_b_pieces, gb.player_c_pieces, gb.player_d_pieces, gb.gameId
    INTO playerPieceA_val, playerPieceB_val, playerPieceC_val, playerPieceD_val, gameId_val
    FROM gameBoard gb
             JOIN player_pieces ppa ON gb.player_a_pieces = ppa.pieceId
             JOIN player_pieces ppb ON gb.player_b_pieces = ppb.pieceId
             JOIN player_pieces ppc ON gb.player_c_pieces = ppc.pieceId
             JOIN player_pieces ppd ON gb.player_d_pieces = ppd.pieceId
    WHERE gb.gameId = OLD.gameId;  -- Use OLD to reference the values before the update



    SELECT count(*) into won
    FROM player_pieces
    WHERE pieceId = playerPieceA_val and 58 in (piece1, piece2, piece3, piece4);

    INSERT INTO log SELECT now(), CONCAT_WS(', ','gotInside',won);

    -- If all pieces of player_A are on location 58, update gameStatus to player_a_won
    IF (won=1) THEN
        INSERT INTO log SELECT now(), CONCAT_WS(', ','truetrueingotInside',won);

        UPDATE gameBoard SET gameStatus = 'player_a_won' WHERE gameId = gameId_val;
    END IF;


    SELECT 64 in (piece1, piece2, piece3, piece4)
    INTO won
    FROM player_pieces
    WHERE pieceId = playerPieceB_val;

    -- If all pieces of player_B are on location 64, update gameStatus to player_b_won
    IF (won=1) like 64 THEN
        UPDATE gameBoard SET gameStatus = 'player_b_won' WHERE gameId = gameId_val;
    END IF;

    SELECT 70 in (piece1, piece2, piece3, piece4)
    INTO won
    FROM player_pieces
    WHERE pieceId = playerPieceC_val;

    -- If all pieces of player_C are on location 70, update gameStatus to player_c_won
    IF (won=1) like 70 THEN
        UPDATE gameBoard SET gameStatus = 'player_c_won' WHERE gameId = gameId_val;
    END IF;


    SELECT 76 in (piece1, piece2, piece3, piece4)
    INTO won
    FROM player_pieces
    WHERE pieceId = playerPieceD_val;

    -- If all pieces of player_D are on location 76, update gameStatus to player_d_won
    IF (won=1) like 76 THEN
        UPDATE gameBoard SET gameStatus = 'player_d_won' WHERE gameId = gameId_val;
    END IF;



END;

create index player_pieces_gameBoard_gameId_fk
    on player_pieces (pieceId);

alter table player_pieces
    modify pieceId int auto_increment;

create
    definer = kastik@localhost function createRoom(sessionToken_param varchar(255), roomName_param varchar(255)) returns tinyint(1)
begin
    declare userId_val varchar(255);

    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;


    if exists(select * from gameRooms where roomName= roomName_param) then
        signal sqlstate '45000' set message_text = 'Room name already exists';
    else
        insert into gameRooms(roomName,roomCreator) value (roomName_param,userId_val);
        return true;
    end if;
end;

create
    definer = kastik@localhost function createUser(username_param varchar(255), password_param varchar(255)) returns tinyint(1)
begin
    if exists(select * from users where username= username_param)then
        signal sqlstate '45000' set message_text = 'Username already exists';
    else
        insert into users(username,password,sessionToken) values (username_param,password_param,LEFT(UUID(), 8));
        return true;
    end if;
end;

create
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
    from gameBoard
             join gameRooms on room = roomName
             join player_pieces on gameBoard.player_a_pieces = pieceId
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
        from gameBoard
                 join gameRooms on room = roomName
                 join player_pieces on gameBoard.player_b_pieces = pieceId
        where roomName = gameRoomName_val;
    end if;

    if exists(select 1 from gameRooms where roomName = gameRoomName_val and player_c is not null) then
        select json_set(playerPieces_val, '$.player_c_pieces', json_object(
                'piece1', piece1,
                'piece2', piece2,
                'piece3', piece3,
                'piece4', piece4
                                                               ))
        into playerPieces_val
        from gameBoard
                 join gameRooms on room = roomName
                 join player_pieces on gameBoard.player_c_pieces = pieceId
        where roomName = gameRoomName_val;
    end if;

    if exists(select 1 from gameRooms where roomName = gameRoomName_val and player_d is not null) then
        select json_set(playerPieces_val, '$.player_d_pieces', json_object(
                'piece1', piece1,
                'piece2', piece2,
                'piece3', piece3,
                'piece4', piece4
                                                               ))
        into playerPieces_val
        from gameBoard
                 join gameRooms on room = roomName
                 join player_pieces on gameBoard.player_d_pieces = pieceId
        where roomName = gameRoomName_val;
    end if;

    -- Create the final JSON object with game state information
    return json_object(
            'currentPlayer', currentPlayer_val,
            'gameRoomName', gameRoomName_val,
            'gameStatus', gameStatus_val,
            'playerPieces', playerPieces_val
           );
end;

create
    definer = kastik@localhost function getUserInfo(sessionToken_param varchar(255)) returns longtext
begin
    declare userId_val int;
    declare username_val varchar(255);


-- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;

    select username,userId from users where sessionToken=sessionToken_param into username_val,userId_val;


    return json_object(
            'username',username_val,
            'userId',userId_val
           );
end;

create
    definer = kastik@localhost function initializeGame(sessionToken_param varchar(255)) returns tinyint(1)
begin
    declare userId_val int;
    declare roomCreator_val int;
    declare gameId_val int;
    declare roomName_val varchar(255);
    declare player_b_val int;
    declare player_c_val int;
    declare player_d_val int;
    declare playerNum_val int;
    declare playerA_pieceId int;
    declare playerB_pieceId int;
    declare playerC_pieceId int;
    declare playerD_pieceId int;


    -- Get the user ID associated with the provided session token
    select userId into userId_val
    from users
    where sessionToken = sessionToken_param;

    if userId_val is null then
        -- Invalid session token
        signal sqlstate '45000' set message_text = 'You need to login first';
    end if;

    -- Get the room creator's userId and the roomName
    select roomCreator, roomName into roomCreator_val, roomName_val
    from gameRooms
    where roomCreator = userId_val;

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


    -- Insert initial data into player_pieces table for the roomCreator
    insert into player_pieces(playerId,piece1)
    values (roomCreator_val,2);
    select LAST_INSERT_ID() into playerA_pieceId;


    insert into gameBoard (room,dice, playerTurn, gameStatus, lastPlayerRolledTheDice,player_a_pieces)
    values (roomName_val,0,userId_val,'running',null,playerA_pieceId);
    select LAST_INSERT_ID() into gameId_val;

    -- Insert initial data into player_pieces table for the other players

    if (player_b_val is not null) then
        insert into player_pieces (playerId,piece1) values (player_b_val,15);
        select LAST_INSERT_ID() into playerB_pieceId;
    end if;

    if (player_c_val is not null) then
        insert into player_pieces(playerId,piece1) values (player_c_val,28);
        select LAST_INSERT_ID() into playerC_pieceId;

    end if;

    if (player_d_val is not null ) then
        insert into player_pieces (playerId,piece1) values (player_d_val,41);
        select LAST_INSERT_ID() into playerD_pieceId;
    end if;


    update gameBoard set player_b_pieces= playerB_pieceId,player_c_pieces=playerC_pieceId,player_d_pieces=playerD_pieceId
    where gameId=gameId_val;

    return true;

end;

create
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

    -- Make sure player is not already in the room
    if exists(select 1 from gameRooms
              where roomName=roomName_param and userId_val in (roomCreator,player_b,player_c,player_d)) then
        signal sqlstate '45000' set message_text = 'You are already in this room';

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




    -- Make sure game is not already running or finnished
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

create
    definer = kastik@localhost procedure movePiece(IN sessionToken_param varchar(255), IN pieceSelection_param int)
begin
    declare piece_column_val varchar(255);
    declare isGameRunning_val int;
    declare isPlayersTurn_val int;
    declare lastPlayerRolled_val int;
    declare userId_val int;
    declare gameId_val int;
    declare room_val varchar(255);
    declare player_a_id_val int;
    declare player_b_id_val int;
    declare player_c_id_val int;
    declare player_d_id_val int;
    declare player_a_pieceId_val int;
    declare player_b_pieceId_val int;
    declare player_c_pieceId_val int;
    declare player_d_pieceId_val int;
    declare moveBlocks_val int;
    declare startingPossition_val int;

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
    select count(*),gameId,room,dice,lastPlayerRolledTheDice into isGameRunning_val,gameId_val,room_val,moveBlocks_val,lastPlayerRolled_val
    from gameBoard
             join gameRooms on room = roomName
    where gameStatus = 'running' and userId_val in (roomCreator,player_b,player_c,player_d);

    if isGameRunning_val = 0 then
        -- No running game for the user
        signal sqlstate '45000' set message_text = 'No running game for the user';
    end if;

    -- Check if it is the user's turn
    select count(*) into isPlayersTurn_val
    from gameBoard join gameRooms on room = roomName
    where room=room_val and playerTurn = userId_val;

    if isPlayersTurn_val = 0 then
        -- Not their turn
        signal sqlstate '45000' set message_text = 'Not your turn yet';
    end if;

    if (lastPlayerRolled_val!=userId_val) then
        signal sqlstate '45000' set message_text = 'You need to roll the dice first';
    end if;


    if (moveBlocks_val < 1 or moveBlocks_val > 6) then
        signal sqlstate '45000' set message_text = 'Illegal move';
    end if;


    select player_a_pieces,player_b_pieces,player_c_pieces,player_d_pieces
    into player_a_pieceId_val,player_b_pieceId_val,player_c_pieceId_val,player_d_pieceId_val
    from gameBoard join gameRooms on gameBoard.room = gameRooms.roomName
    where gameId=gameId_val;


    select playerId
    into player_a_id_val
    from player_pieces join gameBoard on player_pieces.pieceId = gameBoard.player_a_pieces or player_pieces.pieceId = gameBoard.player_b_pieces or player_pieces.pieceId = gameBoard.player_c_pieces or player_pieces.pieceId = gameBoard.player_d_pieces
    where pieceId=player_a_pieceId_val and gameId=gameId_val;


    select playerId
    into player_b_id_val
    from player_pieces join gameBoard on player_pieces.pieceId = gameBoard.player_a_pieces or player_pieces.pieceId = gameBoard.player_b_pieces or player_pieces.pieceId = gameBoard.player_c_pieces or player_pieces.pieceId = gameBoard.player_d_pieces
    where pieceId=player_b_pieceId_val and gameId=gameId_val;

    select playerId
    into player_c_id_val
    from player_pieces join gameBoard on player_pieces.pieceId = gameBoard.player_a_pieces or player_pieces.pieceId = gameBoard.player_b_pieces or player_pieces.pieceId = gameBoard.player_c_pieces or player_pieces.pieceId = gameBoard.player_d_pieces
    where pieceId=player_c_pieceId_val and gameId=gameId_val;

    select playerId
    into player_d_id_val
    from player_pieces join gameBoard on player_pieces.pieceId = gameBoard.player_a_pieces or player_pieces.pieceId = gameBoard.player_b_pieces or player_pieces.pieceId = gameBoard.player_c_pieces or player_pieces.pieceId = gameBoard.player_d_pieces
    where pieceId=player_d_pieceId_val and gameId=gameId_val;


    -- When user rolls a 6 then he playes again, don't change playerTurn
    if (moveBlocks_val!=6) then
        -- Update the player_turn column in the gameBoard table with the userId of the next player from player_pieces
        update gameBoard
        set playerTurn = case
                             when player_a_id_val = userId_val then
                                 coalesce(player_b_id_val, player_c_id_val, player_d_id_val)
                             when player_b_id_val = userId_val then
                                 coalesce(player_c_id_val, player_d_id_val, player_a_id_val)
                             when player_c_id_val = userId_val then
                                 coalesce(player_d_id_val, player_a_id_val, player_b_id_val)
                             when player_d_id_val = userId_val then
                                 coalesce(player_a_id_val, player_b_id_val, player_c_id_val)
            end
        where gameId=gameId_val;

        -- Make sure the lastPlayerRolledTheDice doesn't have the current player so he can roll again
    else

        update gameBoard
        set lastPlayerRolledTheDice = case
                                          when player_a_id_val = userId_val then
                                              coalesce(player_d_id_val,player_c_id_val,player_b_id_val)
                                          when player_b_id_val = userId_val then
                                              coalesce(player_a_id_val, player_d_id_val, player_c_id_val)
                                          when player_c_id_val = userId_val then
                                              coalesce(player_b_id_val, player_a_id_val, player_d_id_val)
                                          when player_d_id_val = userId_val then
                                              coalesce(player_c_id_val, player_b_id_val, player_a_id_val)
            end
        where gameId=gameId_val;



    end if;

    -- Find the value null should be replaced for each user
    select
        case
            when player_a_id_val = userId_val then 2
            when player_b_id_val = userId_val then 15
            when player_c_id_val = userId_val then 28
            when player_d_id_val = userId_val then 41
            end
    into startingPossition_val
    from gameBoard
    where gameId=gameId_val;


    -- IF !PLAYER_A
    if (player_a_id_val!=userId_val) then
        SET @sql = CONCAT(
                'UPDATE player_pieces
                 JOIN gameBoard ON playerId = ', userId_val,
                ' SET ', piece_column_val, ' = CASE',
                ' WHEN ', piece_column_val, ' IS NULL THEN (COALESCE(', piece_column_val, ',', startingPossition_val, ') + ', moveBlocks_val, ' )',
                ' WHEN ', piece_column_val, ' = 52 THEN (', piece_column_val, ' = ', moveBlocks_val, ' )',
                ' WHEN ', piece_column_val, ' = 51 AND ', moveBlocks_val, '  BETWEEN 2 AND 6 THEN (', moveBlocks_val, '  - 52)',
                ' WHEN ', piece_column_val, ' = 50 AND ', moveBlocks_val, '  BETWEEN 3 AND 6 THEN (', moveBlocks_val, '  - 52)',
                ' WHEN ', piece_column_val, ' = 49 AND ', moveBlocks_val, '  BETWEEN 4 AND 6 THEN (', moveBlocks_val, '  - 52)',
                ' WHEN ', piece_column_val, ' = 48 AND ', moveBlocks_val, '  BETWEEN 5 AND 6 THEN (', moveBlocks_val, '  - 52)',
                ' WHEN ', piece_column_val, ' = 47 AND ', moveBlocks_val, '  = 6 THEN (', moveBlocks_val, '  - 52)',
                ' END
                 WHERE gameId = ', gameId_val
                   );
        -- IF PLAYER_A
    else
        set @sql = concat('update player_pieces join gameBoard on playerId = ', userId_val, ' set ', piece_column_val, ' = COALESCE(', piece_column_val, ',',startingPossition_val,' ) + ', moveBlocks_val, '  where gameId = ',gameId_val);
    end if;
    -- Prepare and execute the dynamic SQL

    prepare stmt from @sql;
    execute stmt;
    deallocate prepare stmt;
end;

create
    definer = kastik@localhost function updateDiceValue(sessionToken_param varchar(255), newValue_param int) returns tinyint(1)
begin
    declare userId_val int;
    declare isPlayersTurn_val int;
    declare room_val varchar(255);
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


    -- Check if there is a currently running game for the user and get the room
    select count(*),room into isGameRunning_val,room_val
    from gameBoard
             join gameRooms on room = roomName
    where gameStatus = 'running' and userId_val in (roomCreator,player_b,player_c,player_d);


    -- Check if there is a currently running game for the user
    if isGameRunning_val = 0 then
        -- No running game for the user
        signal sqlstate '45000' set message_text = 'You are not currently in any running game';
    end if;

    -- Get the current player's turn
    select count(*) into isPlayersTurn_val
    from gameBoard
             join gameRooms on room = roomName
    where room=room_val and playerTurn = userId_val;

    -- Check if it's the player's turn
    if isPlayersTurn_val=0 then
        -- It's not the player's turn
        signal sqlstate '45000' set message_text = 'It is not your turn yet';
    end if;

    -- Check if player rolled the dice for the first time
    select lastPlayerRolledTheDice into diceTurn_val
    from gameBoard
             join gameRooms on room = roomName
    where (roomCreator = userId_val or player_b = userId_val or player_c = userId_val or player_d = userId_val) and gameStatus = 'running';

    if diceTurn_val = userId_val then
        -- Player tryied to roll it again
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

