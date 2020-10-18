pragma solidity >= 0.6 <0.8;

import "https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/DCAFactory.sol";
import "https://github.com/ETH-Pantheon/Dollar-Cost-Averaging/blob/master/contracts/DCA.sol";
contract Athene{
    address payable admin;
    DCAFactory factory;
    
    constructor() public {
        admin = msg.sender;
        DCA dca = new DCA();
        factory = new DCAFactory(address(dca)); 
    }
    
    function newImplementation(address _impl) public {
        require(admin==msg.sender);
        factory.registerImplementation(_impl);
    }
    
    function withdrawAll(address[] memory tokens) public returns(bool){
        require(msg.sender==admin);
        withdrawETH();
        for(uint256 i=0;i<tokens.length;i++){
            withdrawToken(tokens[i]);
        }
        return true;
    }
    
    function withdrawETH() public{
        require(msg.sender==admin);
        admin.transfer(address(this).balance);
    }
    
    function withdrawToken(address token) public {
        require(msg.sender==admin);
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(admin,balance);
    }
}
