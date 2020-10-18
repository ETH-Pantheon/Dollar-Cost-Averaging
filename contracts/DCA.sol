pragma solidity >= 0.5 < 0.8;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol'; // ERC20 Interface
import 'https://github.com/ETH-Pantheon/Aion/blob/master/contracts/aionInterface.sol'; //Aion Interface
import './uniswapInterfaceV1.sol';
import "https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/SafeMath.sol";

contract DCA{
    using SafeMath for uint256;
    
    address implementation;
    address registryAddress;
    //----------------------------
    address payable private owner;
    address payable private creator; 
    UniswapFactory uniswapInstance;
    Aion aion;
    uint256 gasAmount;
    uint256 maxGasPrice;

    struct subsInfo{
        address tokenToSell;
        address tokenToBuy;
        uint256 amountToSell;
        uint256 interval;
    }
    
    mapping(bytes32=>subsInfo) subscriptions;
    
    event swapExecuted(address tokenSold, address indexed tokenBought, uint256 amountSold, uint256 amountBought, uint256 indexed aionID);
    event buyEther(address tokenToSell, uint256 amountEther);
    constructor() public payable {
    }



    // ************************************************************************************************************************************************
    function setup(address owner_, address _creator) payable public returns(bool){
        require(owner==address(0));
        uniswapInstance = UniswapFactory(0xD3E51Ef092B2845f10401a0159B2B96e8B6c3D30);
        aion = Aion(0x2fC197cD7897f41957F72e8E390d5a7cF2858CBF);
        owner = payable(owner_);
        creator = payable(_creator);
        return true;
    }



    
    function SubscribeDCA(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell, uint256 gasLimit, uint256 gasPrice) public payable {
        require(msg.sender == owner);
        gasAmount = gasLimit;
        maxGasPrice = gasPrice;
        address exchangeAddress = uniswapInstance.getExchange(tokenToSell);
        IERC20(tokenToSell).approve(exchangeAddress, uint256(-1));
        TokenToToken(tokenToSell, tokenToBuy, interval, amountToSell);
    }
    
    function SubscribeDCA(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell, uint256 refillEther, uint256 gasLimit, uint256 gasPrice) public payable {
        require(msg.sender == owner);
        gasAmount = gasLimit;
        maxGasPrice = gasPrice;
        address exchangeAddress = uniswapInstance.getExchange(tokenToSell);
        IERC20(tokenToSell).approve(exchangeAddress, uint256(-1));
        TokenToToken(tokenToSell, tokenToBuy, interval, amountToSell,refillEther);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    function TokenToToken(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell) public payable{
        IERC20(tokenToSell).transferFrom(owner, address(this), amountToSell);
        uint256 fee = amountToSell.mul(4).div(10000);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSell);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        uint256 tokens_bought = exchange.tokenToTokenSwapInput(amountToSell.sub(fee), 1, 1, now, tokenToBuy);
        IERC20(tokenToSell).transfer(creator, fee);
        
        uint256 callCost = gasAmount*maxGasPrice + aion.serviceFee();
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToToken(address,address,uint256,uint256)')),tokenToSell,tokenToBuy,interval,amountToSell); 
        (uint256 aionID, address aionClientAccount) = aion.ScheduleCall{value:callCost}(now + interval, address(this), 0, gasAmount, maxGasPrice, data, true);
        require(msg.sender == owner || msg.sender==aionClientAccount);
        emit swapExecuted(tokenToSell, tokenToBuy, amountToSell, tokens_bought, aionID);
    }
    

    
    function TokenToToken(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell, uint256 refillEther) public payable{
        IERC20(tokenToSell).transferFrom(owner, address(this), amountToSell);
        uint256 fee = amountToSell.mul(4).div(10000);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSell);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        uint256 tokens_bought = exchange.tokenToTokenSwapInput(amountToSell.sub(fee), 1, 1, now, tokenToBuy);
        IERC20(tokenToSell).transfer(creator, fee);
        
        uint256 callCost = gasAmount*maxGasPrice + aion.serviceFee();
        if(address(this).balance<callCost){
            TokenToETH(tokenToSell, refillEther);
        }
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToToken(address,address,uint256,uint256)')),tokenToSell,tokenToBuy,interval,amountToSell); 
        (uint256 aionID, address aionClientAccount) = aion.ScheduleCall{value:callCost}(now + interval, address(this), 0, gasAmount, maxGasPrice, data, true);
        require(msg.sender == owner || msg.sender==aionClientAccount);
        emit swapExecuted(tokenToSell, tokenToBuy, amountToSell, tokens_bought, aionID);
    }
    
    
    
    // ************************************************************************************************************************************************
    function TokenToETH(address tokenToSell, uint256 amountEther) internal returns(uint256 amountSold){
        IERC20 tokenContract = IERC20(tokenToSell);
        tokenContract.transferFrom(owner, address(this), amountEther);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSell);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        amountSold = exchange.tokenToEthSwapOutput(amountEther, uint256(-1), now);
        emit buyEther(tokenToSell, amountEther);
    }
    
    
    
    
    // ************************************************************************************************************************************************

    function editDCA(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell, uint256 blocknumber, uint256 value, uint256 gaslimit, uint256 gasprice, uint256 fee, bytes memory data, uint256 aionId) public {
        require(msg.sender == owner);
        cancellAionTx(blocknumber, value, gaslimit, gasprice, fee, data, aionId);
        TokenToToken(tokenToSell,tokenToBuy,interval,amountToSell);
    }
    
    function editDCA(address tokenToSell, address tokenToBuy, uint256 interval, uint256 amountToSell, uint256 refillEther, uint256 blocknumber, uint256 value, uint256 gaslimit, uint256 gasprice, uint256 fee, bytes memory data, uint256 aionId) public {
        require(msg.sender == owner);
        cancellAionTx(blocknumber, value, gaslimit, gasprice, fee, data, aionId);
        TokenToToken(tokenToSell,tokenToBuy,interval,amountToSell,refillEther);
    }

    function cancellAionTx(uint256 blocknumber, uint256 value, uint256 gaslimit, uint256 gasprice, uint256 fee, bytes memory data, uint256 aionId) public returns(bool){
        require(msg.sender == owner);
        require(aion.cancellScheduledTx(blocknumber, address(this), address(this), value, gaslimit, gasprice, fee, data, aionId, true));
    }

    // **********************************************************************************************
    function withdrawToken(address token) public {
        require(msg.sender==owner);
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(owner,balance);
    }
    
    
    function withdrawETH() public{
        require(msg.sender==owner);
        owner.transfer(address(this).balance);
    }
    
    function withdrawAll(address[] memory tokens) public returns(bool){
        require(msg.sender==owner);
        withdrawETH();
        for(uint256 i=0;i<tokens.length;i++){
            withdrawToken(tokens[i]);
        }
        return true;
    }

    
    
    
    // ************************************************************************************************************************************************
    function getOwner() view public returns(address){
        return owner;
    }
    
    function getAionClientAccount() view public returns(address){
        return aion.clientAccount(address(this));
    }
    
    
    function updateGas(uint256 gasAmount_, uint256 maxGasPrice_) public {
        require(msg.sender==owner);
        gasAmount = gasAmount_;
        maxGasPrice = maxGasPrice_;
    }



    // ************************************************************************************************************************************************
    receive() external payable {
        
    }
    
    
}
