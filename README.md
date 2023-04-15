# FT5004_FinalProj

# Description
The Rock Paper Scissors game implemented here is 3-player version game. The smart contract is written in Solidity language in Remox IDE. This can be deployed onto Ethereum Blockchain. The game logic is as follows:

1. Player A places a bet and makes a move. Player A then waits for players B and C to place their bets and make corresponding moves. 
2. Once all 3 players make move, each of them reveal their move and player gets verified by the smart contract.
3. If all 3 players play the same move, the game results in a draw and each player gets their own bet back.
4. If each of the 3 players play a different move, then this will also result in a draw and each player gets their own bet back. 
5. If one player plays a move (E.g. Rock) and the other 2 players play a different move (E.g., Scissors), the player who played Rock will win the game and receive all the money from the betting pool.
6. If two players play the same move (E.g. Rock) and the remaining player played a different move (E.g., Scissors), the 2 players will win the game. Here the betting pool will be divided into half and given to each winner.
