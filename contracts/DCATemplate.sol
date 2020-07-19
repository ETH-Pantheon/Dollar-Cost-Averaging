pragma solidity >=0.6;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol'; // ERC20 Interface
import 'https://github.com/ETH-Pantheon/Aion/blob/master/contracts/aionInterface.sol'; //Aion Interface
import 'https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/uniswapInterfaceV1.sol'; //uniswap v1 interface


contract DCA{
    
    address payable private owner;
    UniswapFactory uniswapInstance;
    Aion aion;
    uint256 gasAmount;
    uint256 maxGasPrice;
    address[] tokenList;
    
    struct ETHToTokenInfo{
        uint256 etherToSell;
        uint256 interval;
        bool isActive;
        uint nextPurchase;
    }
    
    struct TokenToETHInfo{
        uint256 tokensToSell;
        uint256 interval;
        bool isActive;
        uint nextPurchase;
    }
    
    struct TokenToTokenInfo{
        uint256 tokensToSell;
        address tokenToBuyAddress;
        uint256 interval;
        bool isActive;
        uint nextPurchase;
    }
    
    mapping(address => ETHToTokenInfo) private ETHToTokenSubs;
    mapping(address => TokenToETHInfo) private TokenToETHSubs;
    mapping(address => TokenToTokenInfo) private TokenToTokenSubs;
    mapping(address=>bool) private TokenExist;

    event ETHToTokenPurchase(address indexed token, uint256 tokensBought, uint256 etherSold);
    event TokenToETHPurchase(address indexed token, uint256 tokensSold, uint256 etherBought);
    event TokenToTokenPurchase(address indexed tokenSold, address indexed tokenBought, uint256 tokensSold, uint256 etherBought);

    constructor() public payable {
    }



    // ************************************************************************************************************************************************
    function setup(address owner_) payable public returns(bool){
        require(owner==address(0));
        uniswapInstance = UniswapFactory(0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351);
        aion = Aion(0xFcFB45679539667f7ed55FA59A15c8Cad73d9a4E);
        owner = payable(owner_);
        return true;
    }



    // ************************************************************************************************************************************************
    function SubscribeEtherToToken(address tokenAddress, uint256 interval, uint256 etherToSell) public {
        require(msg.sender == owner);
        registerToken(tokenAddress);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        ETHToTokenSubs[tokenAddress] = ETHToTokenInfo(etherToSell, interval, true, nextPurchase);
        ETHToToken(tokenAddress);
    }
    
    
    function ETHToToken(address tokenAddress) public returns(uint256 tokens_bought){
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress]; 
        require(info.isActive);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        tokens_bought = exchange.ethToTokenSwapInput{value: info.etherToSell}(1, now);
        info.nextPurchase += info.interval;
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('ETHToToken(address)')),tokenAddress); 
        uint256 callCost = gasAmount*maxGasPrice + aion.serviceFee();
        (, address aionClientAccount) = aion.ScheduleCall{value:callCost}( info.nextPurchase, address(this), 0, gasAmount, maxGasPrice, data, true);
        require(msg.sender == owner || msg.sender==aionClientAccount);
        
        emit ETHToTokenPurchase(tokenAddress, tokens_bought, info.etherToSell); 
    }
    
    
    
    
    // ************************************************************************************************************************************************
    function SubscribeTokenToEther(address tokenAddress, uint256 interval, uint256 tokensToSell) public {
        require(msg.sender == owner);
        registerToken(tokenAddress);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        TokenToETHSubs[tokenAddress] = TokenToETHInfo(tokensToSell, interval, true, nextPurchase);
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
        info.nextPurchase += info.interval;
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToETH(address)')),tokenAddress); 
        uint256 callCost = gasAmount*maxGasPrice + aion.serviceFee();
        (, address aionClientAccount) = aion.ScheduleCall{value:callCost}( info.nextPurchase, address(this), 0, gasAmount, maxGasPrice, data, true);
        require(msg.sender == owner || msg.sender==aionClientAccount);
        
        emit TokenToETHPurchase(tokenAddress, info.tokensToSell, eth_bought);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    // Token to token    
    function SubscribeTokenToToken(address tokenToSellAddress, address tokenToBuyAddress, uint256 interval, uint256 tokensToSell) public {
        require(msg.sender == owner);
        registerToken(tokenToBuyAddress);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenToSellAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        TokenToTokenSubs[tokenToSellAddress] = TokenToTokenInfo(tokensToSell, tokenToBuyAddress, interval, true, nextPurchase);
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
        info.nextPurchase += info.interval;
        
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256('TokenToToken(address)')),tokenToSellAddress); 
        uint256 callCost = gasAmount*maxGasPrice + aion.serviceFee();
        (, address aionClientAccount) = aion.ScheduleCall{value:callCost}(info.nextPurchase, address(this), 0, gasAmount, maxGasPrice, data, true);
        require(msg.sender == owner || msg.sender==aionClientAccount);
    }
    
    
    
    
    // ************************************************************************************************************************************************
    function editEtherToTokenSubs(address tokenAddress, uint256 interval, uint256 etherToSell, bool activate) public {
        require(msg.sender == owner);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        ETHToTokenSubs[tokenAddress] = ETHToTokenInfo(etherToSell, interval, activate, nextPurchase);
    }


    function editTokenToEtherSubs(address tokenAddress, uint256 interval, uint256 tokensToSell, bool activate) public {
        require(msg.sender == owner);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        TokenToETHSubs[tokenAddress] = TokenToETHInfo(tokensToSell, interval, activate, nextPurchase);

    }

    function editTokenToTokenSubs(address tokenToSellAddress, address tokenToBuyAddress, uint256 interval, uint256 tokensToSell, bool activate) public {
        require(msg.sender == owner);
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenToSellAddress];
        uint256 nextPurchase = info.nextPurchase==0 ? now + interval: info.nextPurchase;
        TokenToTokenSubs[tokenToSellAddress] = TokenToTokenInfo(tokensToSell, tokenToBuyAddress, interval, activate, nextPurchase);

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
        return aion.clientAccount(address(this));
    }
    
    
    function getETHToTokenSubs(address tokenAddress) view public returns(uint256 etherToSell, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress];
        return (info.etherToSell, info.interval, gasAmount, maxGasPrice, info.isActive);
    }
    
    function geTokenToETHSubs(address tokenAddress) view public returns(uint256 tokensToSell, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        TokenToETHInfo storage info = TokenToETHSubs[tokenAddress];
        return (info.tokensToSell, info.interval, gasAmount, maxGasPrice, info.isActive);
    }
    
    
    function geTokenToTokenSubs(address tokenAddress) view public returns(uint256 tokensToSell, address tokenToBuyAddress, uint256 interval, uint256 gas, uint256 gasPrice, bool isActive){
        TokenToTokenInfo storage info = TokenToTokenSubs[tokenAddress];
        return (info.tokensToSell, info.tokenToBuyAddress, info.interval, gasAmount, maxGasPrice, info.isActive);
    }
    
    function updateGas(uint256 gasAmount_, uint256 maxGasPrice_) public {
        require(msg.sender==owner);
        gasAmount = gasAmount_;
        maxGasPrice = maxGasPrice_;
    }


    function registerToken(address tokenAddress) internal {
        if(TokenExist[tokenAddress]==true) return;
        tokenList.push() = tokenAddress;
        TokenExist[tokenAddress] == true;
    }
    
    function getTokens() public view returns (address[] memory){
        return tokenList;
    }


    // ************************************************************************************************************************************************
    receive() external payable {
        
    }
    

    
    
    
    // ************************************************************************************************************************************************
    function destroy() public {
        selfdestruct(msg.sender);
    }
    
    
}
