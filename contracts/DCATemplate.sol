pragma solidity >=0.6;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol'; // ERC20 Interface
import 'https://github.com/ETH-Pantheon/Aion/blob/master/contracts/aionInterface.sol'; //Aion Interface
import 'https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/uniswapInterfaceV1.sol'; //uniswap v1 interface


contract DCA{
    
    address payable private owner;
    address payable private aionClientAccount;
    UniswapFactory uniswapInstance;
    Aion aion;

    struct ETHToTokenInfo{
        uint256 etherToSell;
        uint256 interval;
        uint256 gas;
        uint256 gasPrice;
        bool isActive;
    }
    
    struct TokenToETHInfo{
        uint256 tokensToSell;
        uint256 interval;
        uint256 gas;
        uint256 gasPrice;
        bool isActive;
    }
    
    struct TokenToTokenInfo{
        uint256 tokensToSell;
        address tokenToBuyAddress;
        uint256 interval;
        uint256 gas;
        uint256 gasPrice;
        bool isActive;
    }
    
    mapping(address => ETHToTokenInfo) private ETHToTokenSubs;
    mapping(address => TokenToETHInfo) private TokenToETHSubs;
    mapping(address => TokenToTokenInfo) private TokenToTokenSubs;
    

    constructor() public payable {
    }



    // ************************************************************************************************************************************************
    function setup() payable public {
        require(owner==address(0));
        uniswapInstance = UniswapFactory(0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351);
        aion = Aion(0xFcFB45679539667f7ed55FA59A15c8Cad73d9a4E);
        owner = msg.sender;
        uint256 callCost = 100000*tx.gasprice + aion.serviceFee();
        (, address account) = aion.ScheduleCall{value:callCost}( block.timestamp + 1 days, address(this), 0, 100000, tx.gasprice, hex'00', true);
        aionClientAccount = payable(account);
    }



    // ************************************************************************************************************************************************
    function SubscribeEtherToToken(address tokenAddress, uint256 interval, uint256 etherToSell, uint256 gas, uint256 gasPrice) public {
        require(aionClientAccount!=address(0),'Aion account has not been setup');
        require(msg.sender==owner);
        ETHToTokenSubs[tokenAddress] = ETHToTokenInfo(etherToSell, interval, gas, gasPrice, true);
        ETHToToken(tokenAddress);
    }
    
    
    function ETHToToken(address tokenAddress) public returns(uint256 tokens_bought){
        require( (msg.sender == aionClientAccount) || (msg.sender == owner));
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress]; 
        require(info.isActive);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        tokens_bought = exchange.ethToTokenSwapInput{value: info.etherToSell}(1, now);
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('ETHToToken(address)')),tokenAddress); 
        uint256 callCost = info.gas*info.gasPrice + aion.serviceFee();
        aion.ScheduleCall{value:callCost}( block.timestamp + info.interval, address(this), 0, info.gas, info.gasPrice, data, true);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    function SubscribeTokenToEther(address tokenAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice) public {
        TokenToETHSubs[tokenAddress] = TokenToETHInfo(tokensToSell, interval, gas, gasPrice, true);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        IERC20(tokenAddress).approve(exchangeAddress, uint256(-1));
        TokenToETH(tokenAddress);
    }
    

    function TokenToETH(address tokenAddress) public returns(uint256 eth_bought){
        TokenToETHInfo storage info = TokenToETHSubs[tokenAddress];
        require(info.isActive);
        IERC20 tokenContract = IERC20(tokenAddress);
        tokenContract.transferFrom(owner, address(this), info.tokensToSell);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        eth_bought = exchange.tokenToEthSwapInput(info.tokensToSell, 1, now);
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToETH(address)')),tokenAddress); 
        uint256 callCost = info.gas*info.gasPrice + aion.serviceFee();
        aion.ScheduleCall{value:callCost}( block.timestamp + info.interval, address(this), 0, info.gas, info.gasPrice, data, true);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    // Token to token    
    function SubscribeTokenToToken(address tokenToSellAddress, address tokenToBuyAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice) public {
        TokenToTokenSubs[tokenToSellAddress] = TokenToTokenInfo(tokensToSell, tokenToBuyAddress, interval, gas, gasPrice, true);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSellAddress);
        IERC20(tokenToSellAddress).approve(exchangeAddress, uint256(-1));
        TokenToToken(tokenToSellAddress);
    }
    
    
    function TokenToToken(address tokenToSellAddress) public payable returns(uint256 tokens_bought){
        TokenToTokenInfo storage info = TokenToTokenSubs[tokenToSellAddress];
        require(info.isActive);
        IERC20(tokenToSellAddress).transferFrom(owner, address(this), info.tokensToSell);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSellAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        tokens_bought = exchange.tokenToTokenSwapInput(info.tokensToSell, 1, 1, now, info.tokenToBuyAddress);
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToToken(address)')),tokenToSellAddress); 
        uint256 callCost = info.gas*info.gasPrice + aion.serviceFee();
        aion.ScheduleCall{value:callCost}( block.timestamp + info.interval, address(this), 0, info.gas, info.gasPrice, data, true);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    function editEtherToTokenSubs(address tokenAddress, uint256 interval, uint256 etherToSell, uint256 gas, uint256 gasPrice, bool activate) public {
        ETHToTokenSubs[tokenAddress] = ETHToTokenInfo(etherToSell, interval, gas, gasPrice, activate);
    }


    function editTokenToEtherSubs(address tokenAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice, bool activate) public {
        TokenToETHSubs[tokenAddress] = TokenToETHInfo(tokensToSell, interval, gas, gasPrice, activate);

    }

    function editTokenToTokenSubs(address tokenToSellAddress, address tokenToBuyAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice, bool activate) public {
        TokenToTokenSubs[tokenToSellAddress] = TokenToTokenInfo(tokensToSell, tokenToBuyAddress, interval, gas, gasPrice, activate);
    }
    
    
    

    // ************************************************************************************************************************************************
    function withdrawToken(address tokenAddress) public{
        require(msg.sender==owner);
        IERC20 tokenContract = IERC20(tokenAddress);
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(owner,balance);
    }
    
    
    function withdrawETH() public{
        require(msg.sender==owner);
        owner.transfer(address(this).balance);
    }

    
    
    
    // ************************************************************************************************************************************************
    function getOwner() view public returns(address){
        return owner;
    }
    
    function getAionClientAccount() view public returns(address){
        return aionClientAccount;
    }
    
    
    function getETHToTokenSubs(address tokenAddress) view public returns(uint256 etherToSell, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        return (info.etherToSell, info.interval, info.gas, info.gasPrice, info.isActive);
    }
    
    function geTokenToETHSubs(address tokenAddress) view public returns(uint256 tokensToSell, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        TokenToETHInfo storage info = TokenToETHSubs[tokenAddress];
        return (info.tokensToSell, info.interval, info.gas, info.gasPrice, info.isActive);
    }
    
    
    function geTokenToTokenSubs(address tokenAddress) view public returns(uint256 tokensToSell, address tokenToBuyAddress, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        TokenToTokenInfo storage info = TokenToTokenSubs[tokenAddress];
        return (info.tokensToSell, info.tokenToBuyAddress, info.interval, info.gas, info.gasPrice, info.isActive);
    }




    // ************************************************************************************************************************************************
    receive() external payable {
        
    }
    

    
    
    
    // ************************************************************************************************************************************************
    function destroy() public {
        selfdestruct(msg.sender);
    }
    
    
}
