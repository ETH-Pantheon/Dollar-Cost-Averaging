pragma solidity >= 0.5 < 0.8;

interface IDCA{
    function setup(address owner_, address creator) external returns(bool);
}
