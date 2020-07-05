pragma solidity >=0.6;

abstract contract UniswapFactory {
    // Public Variables
    address public exchangeTemplate;
    uint256 public tokenCount;
    // Create Exchange
    function createExchange(address token) external virtual returns (address exchange);
    // Get Exchange and Token Info
    function getExchange(address token) external view virtual returns (address exchange);
    function getToken(address exchange) external view virtual returns (address token);
    function getTokenWithId(uint256 tokenId) external virtual view returns (address token);
    // Never use
    function initializeFactory(address template) external virtual;
}

abstract contract UniswapExchange {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view virtual returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view virtual returns (address factory);
    // Provide Liquidity
    function addLiquidity(uint256 min_liquidity, uint256 max_tokens, uint256 deadline) external payable virtual returns (uint256);
    function removeLiquidity(uint256 amount, uint256 min_eth, uint256 min_tokens, uint256 deadline) external virtual returns (uint256, uint256);
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold) external view virtual returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view virtual returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view virtual returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view virtual returns (uint256 tokens_sold);
    // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline) external payable virtual returns (uint256  tokens_bought);
    function ethToTokenTransferInput(uint256 min_tokens, uint256 deadline, address recipient) external payable virtual returns (uint256  tokens_bought);
    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline) external payable virtual returns (uint256  eth_sold);
    function ethToTokenTransferOutput(uint256 tokens_bought, uint256 deadline, address recipient) external payable virtual returns (uint256  eth_sold);
    // Trade ERC20 to ETH
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external virtual returns (uint256  eth_bought);
    function tokenToEthTransferInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline, address recipient) external virtual returns (uint256  eth_bought);
    function tokenToEthSwapOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline) external virtual returns (uint256  tokens_sold);
    function tokenToEthTransferOutput(uint256 eth_bought, uint256 max_tokens, uint256 deadline, address recipient) external virtual returns (uint256  tokens_sold);
    // Trade ERC20 to ERC20
    function tokenToTokenSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address token_addr) external virtual returns (uint256  tokens_bought);
    function tokenToTokenTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address token_addr) external virtual returns (uint256  tokens_bought);
    function tokenToTokenSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address token_addr) external virtual returns (uint256  tokens_sold);
    function tokenToTokenTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address token_addr) external virtual returns (uint256  tokens_sold);
    // Trade ERC20 to Custom Pool
    function tokenToExchangeSwapInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address exchange_addr) external virtual returns (uint256  tokens_bought);
    function tokenToExchangeTransferInput(uint256 tokens_sold, uint256 min_tokens_bought, uint256 min_eth_bought, uint256 deadline, address recipient, address exchange_addr) external virtual returns (uint256  tokens_bought);
    function tokenToExchangeSwapOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address exchange_addr) external virtual returns (uint256  tokens_sold);
    function tokenToExchangeTransferOutput(uint256 tokens_bought, uint256 max_tokens_sold, uint256 max_eth_sold, uint256 deadline, address recipient, address exchange_addr) external virtual returns (uint256  tokens_sold);
    // ERC20 comaptibility for liquidity tokens
    bytes32 public name;
    bytes32 public symbol;
    uint256 public decimals;
    function transfer(address _to, uint256 _value) external virtual returns (bool);
    function transferFrom(address _from, address _to, uint256 value) external virtual returns (bool);
    function approve(address _spender, uint256 _value) external virtual returns (bool);
    function allowance(address _owner, address _spender) external view virtual returns (uint256);
    function balanceOf(address _owner) external view virtual returns (uint256);
    function totalSupply() external view virtual returns (uint256);
    // Never use
    function setup(address token_addr) external virtual;
}

abstract contract ERC20 {
    function totalSupply() public view virtual returns (uint);
    function balanceOf(address tokenOwner) public view virtual returns (uint balance);
    function allowance(address tokenOwner, address spender) public view virtual returns (uint remaining);
    function transfer(address to, uint tokens) public virtual returns (bool success);
    function approve(address spender, uint tokens) public virtual returns (bool success);
    function transferFrom(address from, address to, uint tokens) public virtual returns (bool success);
    function buy() public payable virtual returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


contract DCA{
    
    address payable owner;
    UniswapFactory uniswapInstance = UniswapFactory(0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36);
    
    
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
    
    mapping(address => ETHToTokenInfo) public ETHToTokenSubs;
    mapping(address => TokenToETHInfo) public TokenToETHSubs;
    mapping(address => TokenToTokenInfo) public TokenToTokenSubs;
    
    
    constructor() public payable {
    }

    function setup() public {
        require(owner==address(0));
        owner = msg.sender;
    }


    //ETH to token 
    function ETHToToken(address tokenAddress) private returns(uint256 tokens_bought){
        ETHToTokenInfo storage info = ETHToTokenSubs[tokenAddress]; 
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        tokens_bought = exchange.ethToTokenSwapInput{value: info.etherToSell}(1, now);
    }
    
    function escheduleEtherToToken(address tokenAddress, uint256 interval, uint256 etherToSell, uint256 gas, uint256 gasPrice) public {
        ETHToTokenSubs[tokenAddress] = ETHToTokenInfo(etherToSell, interval, gas, gasPrice, true);
        ETHToToken(tokenAddress);
    }
    
    
    // Token to ETH
    function TokenToETH(address tokenAddress) public returns(uint256 eth_bought){
        TokenToETHInfo storage info = TokenToETHSubs[tokenAddress];
        ERC20 tokenContract = ERC20(tokenAddress);
        tokenContract.transferFrom(owner, address(this), info.tokensToSell);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        eth_bought = exchange.tokenToEthSwapInput(info.tokensToSell, 1, now);
    }
    
    function escheduleTokenToEther(address tokenAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice) public {
        TokenToETHSubs[tokenAddress] = TokenToETHInfo(tokensToSell, interval, gas, gasPrice, true);
        address exchangeAddress = uniswapInstance.getExchange(tokenAddress);
        ERC20(tokenAddress).approve(exchangeAddress, uint256(-1));
        TokenToETH(tokenAddress);
    }



    // Token to token    
    function TokenToToken(address tokenToSellAddress) public payable returns(uint256 tokens_bought){
        TokenToTokenInfo storage info = TokenToTokenSubs[tokenToSellAddress];
        ERC20 tokenContract = ERC20(tokenToSellAddress);
        tokenContract.transferFrom(owner, address(this), info.tokensToSell);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSellAddress);
        UniswapExchange exchange = UniswapExchange(exchangeAddress);
        tokens_bought = exchange.tokenToTokenSwapInput(info.tokensToSell, 1, 1, now, info.tokenToBuyAddress);
    }
    
    function escheduleTokenToToken(address tokenToSellAddress, address tokenToBuyAddress, uint256 interval, uint256 tokensToSell, uint256 gas, uint256 gasPrice) public {
        TokenToTokenSubs[tokenToSellAddress] = TokenToTokenInfo(tokensToSell, tokenToBuyAddress, interval, gas, gasPrice, true);
        address exchangeAddress = uniswapInstance.getExchange(tokenToSellAddress);
        ERC20(tokenToSellAddress).approve(exchangeAddress, uint256(-1));
        TokenToToken(tokenToSellAddress);
    }


    

    function withdrawToken(address tokenAddress) public{
        require(msg.sender==owner);
        ERC20 tokenContract = ERC20(tokenAddress);
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(owner,balance);
    }
    
    function withdrawETH() public{
        require(msg.sender==owner);
        owner.transfer(address(this).balance);
    }

    receive() external payable {
        
    }

    
    fallback() external payable {
        
    }
    
    function destroy() public {
        selfdestruct(msg.sender);
    }
    
    
}
