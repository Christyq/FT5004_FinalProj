// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./RPSToken.sol";

contract RockPaperScissorsToken {
    // note: 1 token = 0.5 ether
    uint256 public TOTAL_COMMISSION = 0;         // Commission Fee for smart contract 1 ether
    uint256 constant public COMMISSION_FEE = 1;
    uint256 public BET_MIN = 2;        // The minimum bet 2 token
    uint constant public REVEAL_TIMEOUT = 10 minutes;  // Max delay of revelation phase
    uint256 ContractBalance = 0;

    RPSToken rpsToken; 

    constructor(RPSToken _rpsTokenAddress) {
        rpsToken = _rpsTokenAddress;
    }

    uint public initialBet;                            // Bet of first player
    uint public secondBet;                             // Bet of second player
    uint public thirdBet;                              // Bet of third player
    uint private firstReveal;                          // Moment of first reveal

    enum Moves {None, Rock, Paper, Scissors}
    enum Outcomes {None, PlayerA, PlayerB, PlayerC, Draw, PlayerAB, PlayerBC, PlayerAC}   // Possible outcomes

    // Players' addresses
    address payable playerA;
    address payable playerB;
    address payable playerC;

    // Encrypted moves
    bytes32 private encrMovePlayerA;
    bytes32 private encrMovePlayerB;
    bytes32 private encrMovePlayerC;


    // Clear moves set only after both players have committed their encrypted moves
    Moves private movePlayerA;
    Moves private movePlayerB;
    Moves private movePlayerC;

    /**************************************************************************/
    /*************************** REGISTRATION PHASE ***************************/
    /**************************************************************************/

    // Bet must be greater than a minimum amount and greater than bet of first player
    // modifier validBet() {
    //     uint checkBalance = rpsToken.balanceOf(tx.origin);
    //     require(checkBalance >= BET_MIN + COMMISSION_FEE,"Insufficient amount. Bet needs to be >= value + comission fee.");
    //     _;
    // }

    modifier notAlreadyRegistered() {
        require(msg.sender != playerA && msg.sender != playerB && msg.sender != playerC,"You have already registered!");
        _;
    }

    function userBalance() public view returns(uint256){
        return rpsToken.balanceOf(msg.sender);
    }

    // Register a player.
    // Return player's ID upon successful registration.
    function register(uint256 inputBet) public notAlreadyRegistered returns (uint) {
        uint256 checkBalance = userBalance(); // check current user's token balance 

        require(inputBet <= checkBalance,"Insufficent Funds"); // check if have sufficient amount to place bet 
        require(checkBalance >= (BET_MIN + COMMISSION_FEE),"Bet needs to be >= value + comission fee."); // check valid bet 
        
        TOTAL_COMMISSION = TOTAL_COMMISSION + COMMISSION_FEE;

        if (playerA == address(0x0)) {
            playerA    = payable(msg.sender);
            initialBet = inputBet;
            BET_MIN = inputBet;
            // rpsToken.approve(msg.sender, address(this), inputBet + COMMISSION_FEE);
            // rpsToken.transfer(address(this), inputBet + COMMISSION_FEE);
            return 1;
        } else if (playerB == address(0x0)) {
            playerB = payable(msg.sender);
            secondBet = inputBet;
            // rpsToken.approve(msg.sender, address(this), inputBet + COMMISSION_FEE);
            // rpsToken.transfer(address(this), inputBet + COMMISSION_FEE);
            return 2;
        } else if(playerC == address(0x0)){
            playerC = payable(msg.sender);
            thirdBet = inputBet;
            // rpsToken.approve(msg.sender, address(this), inputBet + COMMISSION_FEE);
            // rpsToken.transfer(address(this), inputBet + COMMISSION_FEE);
            return 3;
        }
        return 0;
    }

    function transferFund(address player, uint256 bet) public payable {
        require (player == playerA || player == playerB || player == playerC, "You have not registered!");
        rpsToken.approve(player, tx.origin, bet + COMMISSION_FEE);
        rpsToken.transferFrom(player, tx.origin, bet + COMMISSION_FEE);
    }

    /**************************************************************************/
    /****************************** COMMIT PHASE ******************************/
    /**************************************************************************/

    modifier isRegistered() {
        require (msg.sender == playerA || msg.sender == playerB || msg.sender == playerC, "You have not registered!");
        _;
    }

    // Save player's encrypted move.
    // Return 'true' if move was valid, 'false' otherwise.
    function play(bytes32 encrMove) public isRegistered returns (bool) {
        if (msg.sender == playerA && encrMovePlayerA == 0x0) {
            encrMovePlayerA = encrMove;
        } else if (msg.sender == playerB && encrMovePlayerB == 0x0) {
            encrMovePlayerB = encrMove;
        } else if (msg.sender == playerC && encrMovePlayerC == 0x0) {
            encrMovePlayerC = encrMove;
        }
        else {
            return false;
        }
        return true;
    }

    /**************************************************************************/
    /****************************** REVEAL PHASE ******************************/
    /**************************************************************************/

    modifier commitPhaseEnded() {
        require(encrMovePlayerA != 0x0 && encrMovePlayerB != 0x0 && encrMovePlayerC != 0x0,"Everyone has not played their move yet.");
        _;
    }

    // Compare clear move given by the player with saved encrypted move.
    // Return clear move upon success, 'Moves.None' otherwise.
    function reveal(string memory clearMove) public isRegistered commitPhaseEnded returns (Moves) {
        bytes32 encrMove = sha256(abi.encodePacked(clearMove));  // Hash of clear input (= "move-password")
        Moves move       = Moves(getFirstChar(clearMove));       // Actual move (Rock / Paper / Scissors)

        // If move invalid, exit
        if (move == Moves.None) {
            return Moves.None;
        }

        // If hashes match, clear move is saved
        if (msg.sender == playerA && encrMove == encrMovePlayerA) {
            movePlayerA = move;
        } else if (msg.sender == playerB && encrMove == encrMovePlayerB) {
            movePlayerB = move;
        } else if (msg.sender == playerC && encrMove == encrMovePlayerC) {
            movePlayerC = move;
        }
        else {
            return Moves.None;
        }

        // Timer starts after first revelation from one of the player
        if (firstReveal == 0) {
            firstReveal = block.timestamp;
        }

        return move;
    }

    // Return first character of a given string.
    function getFirstChar(string memory str) private pure returns (uint) {
        bytes1 firstByte = bytes(str)[0];
        if (firstByte == 0x31) {
            return 1;
        } else if (firstByte == 0x32) {
            return 2;
        } else if (firstByte == 0x33) {
            return 3;
        } else {
            return 0;
        }
    }

    /**************************************************************************/
    /****************************** RESULT PHASE ******************************/
    /**************************************************************************/

    modifier revealPhaseEnded() {
        require((movePlayerA != Moves.None && movePlayerB != Moves.None && movePlayerC != Moves.None) ||
                (firstReveal != 0 && block.timestamp > firstReveal + REVEAL_TIMEOUT),"Reveal Phase not yet ended");
        _;
    }


    // Compute the outcome and pay the winner(s).
    // Return the outcome.
    function getOutcome() public revealPhaseEnded returns (Outcomes) {
        Outcomes outcome;

        if (movePlayerA == movePlayerB && movePlayerB == movePlayerC) {
            outcome = Outcomes.Draw;
        } else if (movePlayerA != movePlayerB && movePlayerB != movePlayerC && movePlayerA != movePlayerC) {
            outcome = Outcomes.Draw;
        } else if ((movePlayerA == Moves.Rock     && movePlayerB == Moves.Scissors && movePlayerC == Moves.Scissors) ||
                   (movePlayerA == Moves.Paper    && movePlayerB == Moves.Rock && movePlayerC == Moves.Rock)     ||
                   (movePlayerA == Moves.Scissors && movePlayerB == Moves.Paper && movePlayerC == Moves.Paper)    ||
                   (movePlayerA != Moves.None     && movePlayerB == Moves.None && movePlayerC == Moves.None)) {
            outcome = Outcomes.PlayerA;
        } else if ((movePlayerB == Moves.Rock     && movePlayerA == Moves.Scissors && movePlayerC == Moves.Scissors) ||
                   (movePlayerB == Moves.Paper    && movePlayerA == Moves.Rock && movePlayerC == Moves.Rock)     ||
                   (movePlayerB == Moves.Scissors && movePlayerA == Moves.Paper && movePlayerC == Moves.Paper)    ||
                   (movePlayerB != Moves.None     && movePlayerA == Moves.None && movePlayerC == Moves.None)) {
            outcome = Outcomes.PlayerB;
        } else if ((movePlayerC == Moves.Rock     && movePlayerA == Moves.Scissors && movePlayerB == Moves.Scissors) ||
                   (movePlayerC == Moves.Paper    && movePlayerA == Moves.Rock && movePlayerB == Moves.Rock)     ||
                   (movePlayerC == Moves.Scissors && movePlayerA == Moves.Paper && movePlayerB == Moves.Paper)    ||
                   (movePlayerC != Moves.None     && movePlayerA == Moves.None && movePlayerB == Moves.None)) {
            outcome = Outcomes.PlayerC;
        } else if ((movePlayerA == Moves.Rock     && movePlayerB == Moves.Rock && movePlayerC == Moves.Scissors) ||
                   (movePlayerA == Moves.Paper    && movePlayerB == Moves.Paper && movePlayerC == Moves.Rock)     ||
                   (movePlayerA == Moves.Scissors && movePlayerB == Moves.Scissors && movePlayerC == Moves.Paper)) {
            outcome = Outcomes.PlayerAB;
        } else if ((movePlayerB == Moves.Rock     && movePlayerC == Moves.Rock && movePlayerA == Moves.Scissors) ||
                   (movePlayerB == Moves.Paper    && movePlayerC == Moves.Paper && movePlayerA == Moves.Rock)     ||
                   (movePlayerB == Moves.Scissors && movePlayerC == Moves.Scissors && movePlayerA == Moves.Paper)) {
            outcome = Outcomes.PlayerBC;
        } else if ((movePlayerC == Moves.Rock     && movePlayerA == Moves.Rock && movePlayerB == Moves.Scissors) ||
                   (movePlayerC == Moves.Paper    && movePlayerA == Moves.Paper && movePlayerB == Moves.Rock)     ||
                   (movePlayerC == Moves.Scissors && movePlayerA == Moves.Scissors && movePlayerB== Moves.Paper)    ||
                   (movePlayerC != Moves.None     && movePlayerA == Moves.None && movePlayerB == Moves.None)) {
            outcome = Outcomes.PlayerAC;
        }

        address payable addrA = playerA;
        address payable addrB = playerB;
        address payable addrC = playerC;
        uint betPlayerA       = initialBet;
        uint betPlayerB       = secondBet;
        uint betPlayerC       = thirdBet;
        reset();  // Reset game before paying to avoid reentrancy attacks
        pay(addrA, addrB, addrC, betPlayerA, betPlayerB, betPlayerC, outcome);

        return outcome;
    }

    // Pay the winner(s).
    function pay(address payable addrA, address payable addrB, address payable addrC, uint betPlayerA, uint betPlayerB, uint betPlayerC, Outcomes outcome) private {
        
        // uint halfBalance = ((address(this).balance - 3*COMMISSION_FEE) * 500 / 1000);

        uint256 halfBalance = (getContractBalance() - TOTAL_COMMISSION) / 2; 

        // A wins, gets the whole pool minus commission fee 
        // B wins, gets the whole pool minus commission fee 
        // C wins, gets the whole pool minus commission fee 
        // AB win, A and B get half minus commission 
        // BC win, B and C get half minus commission 
        // AC win, A and C get half minus commission 
        // draw then all players get back the original bet (minus commision fee) 
        if (outcome == Outcomes.PlayerA) {
            rpsToken.transfer(addrA, getContractBalance() - TOTAL_COMMISSION); 

        } else if (outcome == Outcomes.PlayerB) {
            rpsToken.transfer(addrB, getContractBalance() - TOTAL_COMMISSION);

        } else if (outcome == Outcomes.PlayerC) {
            rpsToken.transfer(addrC, getContractBalance() - TOTAL_COMMISSION);

        } else if (outcome == Outcomes.PlayerAB) {
            rpsToken.transfer(addrA, halfBalance);
            rpsToken.transfer(addrB, halfBalance);

        } else if (outcome == Outcomes.PlayerBC) {
            rpsToken.transfer(addrB, halfBalance);
            rpsToken.transfer(addrC, halfBalance);

        } else if (outcome == Outcomes.PlayerAC) {
            rpsToken.transfer(addrA, halfBalance);
            rpsToken.transfer(addrC, halfBalance);


        } else {
            rpsToken.transfer(addrA, betPlayerA);
            rpsToken.transfer(addrB, betPlayerB);
            rpsToken.transfer(addrC, betPlayerC);
            
        }
    }

    // Reset the game.
    function reset() private {
        initialBet      = 0;
        secondBet       = 0;
        firstReveal     = 0;
        playerA         = payable(address(0x0));
        playerB         = payable(address(0x0));
        playerC         = payable(address(0x0));
        encrMovePlayerA = 0x0;
        encrMovePlayerB = 0x0;
        encrMovePlayerC = 0x0;
        movePlayerA     = Moves.None;
        movePlayerB     = Moves.None;
        movePlayerC     = Moves.None;
    }

    /**************************************************************************/
    /**************************** HELPER FUNCTIONS ****************************/
    /**************************************************************************/

    // Return contract balance
    function getContractBalance() public view returns (uint) {
        return rpsToken.balanceOf(tx.origin);
    }

    // Return player's ID
    function whoAmI() public view returns (uint) {
        if (msg.sender == playerA) {
            return 1;
        } else if (msg.sender == playerB) {
            return 2;
        } else if (msg.sender == playerC) {
            return 3;
        }else {
            return 0;
        }
    }

    // Return 'true' if both players have commited a move, 'false' otherwise.
    function allPlayed() public view returns (bool) {
        return (encrMovePlayerA != 0x0 && encrMovePlayerB != 0x0 && encrMovePlayerC != 0x0);
    }

    // Return 'true' if both players have revealed their move, 'false' otherwise.
    function allRevealed() public view returns (bool) {
        return (movePlayerA != Moves.None && movePlayerB != Moves.None && movePlayerC != Moves.None);
    }

    // Return time left before the end of the revelation phase.
    function revealTimeLeft() public view returns (int) {
        if (firstReveal != 0) {
            return int((firstReveal + REVEAL_TIMEOUT) - block.timestamp);
        }
        return int(REVEAL_TIMEOUT);
    }

}