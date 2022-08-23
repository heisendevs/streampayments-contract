// SPDX-License-Identifier: MIT
// StreamPayments (StreamPayments.sol)

pragma solidity 0.8.15;

import "./contracts/ERC20.sol";
import "./utils/SafeERC20.sol";
import "./access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * @title StreamPayments Contract for StreamPayments.dao
 * @author HeisenDev (www.heisen.dev)
 */
contract StreamPayments is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public uniswapV2RouterBNB;
    IUniswapV2Router02 public uniswapV2RouterBUSD;
    IERC20 public immutable BUSD = IERC20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7);
    IERC20 public immutable BNB = IERC20(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);

    /**
     * Definition of the token parameters
     */
    uint private _tokenTotalSupply = 1000000000 * 10 ** 18;

    bool private firstLiquidityEnabled = true;


    uint public withdrawPrice = 0.005 ether;

    /**
     * Definition of the Project Wallets
     * `addressHeisenDev` Corresponds to the wallet address where the development
     * team will receive their payments
     * `addressMarketing` Corresponds to the wallet address where the funds
     * for marketing will be received
     * `addressTeam` Represents the wallet where teams and other
     * collaborators will receive their payments
     */
    address payable public addressHeisenDev = payable(0x34390458758b6eFaAC5680fBEAb8DE17F2951Ad0);
    address payable public addressMarketing = payable(0x3c1Cd83D8850803C9c42fF5083F56b66b00FBD61);
    address payable public addressTeam = payable(0x63024aC73FE77427F20e8247FA26F470C0D9700B);

    /**
     * Definition of the taxes fees for swaps
     * `taxFeeHeisenDev` 2%  Initial tax fee during presale
     * `taxFeeMarketing` 3%  Initial tax fee during presale
     * `taxFeeTeam` 3%  Initial tax fee during presale
     * `taxFeeLiquidity` 2%  Initial tax fee during presale
     * This value can be modified by the method {updateTaxesFees}
     */
    uint256 public taxFeeHeisenDev = 1;
    uint256 public taxFeeMarketing = 2;
    uint256 public taxFeeTeam = 1;
    uint256 public taxFeeLiquidity = 1;

    /**
     * Definition of pools
     * `_poolHeisenDev`
     * `_poolMarketing`
     * `_poolTeam`
     * `_poolLiquidity`
     */
    uint256 public _poolHeisenDev = 0;
    uint256 public _poolMarketing = 0;
    uint256 public _poolTeam = 0;
    uint256 public _poolLiquidity = 0;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromLimits;
    mapping(address => bool) private automatedMarketMakerPairs;

    event Deposit(address indexed sender, uint amount);
    event Withdraw(uint amount);
    event TeamPayment(uint amount);
    event FirstLiquidityAdded(
        uint256 bnb
    );
    event LiquidityAdded(
        uint256 bnb
    );
    event UpdateTaxesFees(
        uint256 taxFeeHeisenDev,
        uint256 taxFeeMarketing,
        uint256 taxFeeTeam,
        uint256 taxFeeLiquidity
    );
    event UpdateWithdrawOptions(
        uint256 withdrawPrice
    );
    constructor(address _owner1, address _owner2, address _owner3) {
        IUniswapV2Router02 _uniswapV2RouterBNB = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        address _uniswapV2PairBNB = IUniswapV2Factory(_uniswapV2RouterBNB.factory()).createPair(address(this), _uniswapV2RouterBNB.WETH());
        IUniswapV2Router02 _uniswapV2RouterBUSD = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        address _uniswapV2PairBUSD = IUniswapV2Factory(_uniswapV2RouterBUSD.factory()).createPair(address(this), _uniswapV2RouterBUSD.WETH());

        uniswapV2RouterBNB = _uniswapV2Router;
        uniswapV2RouterBUSD = _uniswapV2PairBUSD;

        automatedMarketMakerPairs[_uniswapV2PairBNB] = true;
        automatedMarketMakerPairs[_uniswapV2PairBUSD] = true;

        _isExcludedFromLimits[_uniswapV2PairBNB] = true;
        _isExcludedFromLimits[_uniswapV2PairBUSD] = true;
        _isExcludedFromLimits[address(this)] = true;

        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[addressHeisenDev] = true;
        _isExcludedFromFees[addressMarketing] = true;
        _isExcludedFromFees[addressTeam] = true;
        /*
            _setOwners is an internal function in Ownable.sol that is only called here,
            and CANNOT be called ever again
        */
        _addOwner(_owner1);
        _addOwner(_owner2);
        _addOwner(_owner3);

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(address(this), _tokenTotalSupply);
    }

    /**
     * @dev Fallback function allows to deposit ether.
     */
    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(_msgSender(), msg.value);
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        // if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !(_isExcludedFromFees[from] || _isExcludedFromFees[to]);

        if (takeFee && automatedMarketMakerPairs[from]) {
            uint256 heisenDevAmount = amount.mul(taxFeeHeisenDev).div(100);
            uint256 marketingAmount = amount.mul(taxFeeMarketing).div(100);
            uint256 teamAmount = amount.mul(taxFeeTeam).div(100);
            uint256 liquidityAmount = amount.mul(taxFeeLiquidity).div(100);

            _poolHeisenDev = _poolHeisenDev.add(heisenDevAmount);
            _poolMarketing = _poolMarketing.add(marketingAmount);
            _poolTeam = _poolTeam.add(teamAmount);
            _poolLiquidity = _poolLiquidity.add(liquidityAmount);
        }
        super._transfer(from, to, amount);
    }


    function addLiquidityBNB(uint256 tokens, uint256 bnb) private {
        _approve(address(this), address(uniswapV2RouterBNB), balanceOf(address(this)));
        uniswapV2RouterBNB.addLiquidityETH{value : bnb}(
            address(this),
            tokens,
            0,
            0,
            address(this),
            block.timestamp.add(300)
        );
        emit LiquidityAdded(bnb);
    }

    function deposit (
        address _token,
        uint _amount,
        address _from,
        address _to,
        string _message
    )  external payable {
        IERC20(_token).safeTransferFrom(msg.sender,address(this),_amount);
        proposals.push(Deposit({
            tokenContract: tokenContract,
            creator: _msgSender(),
            from: from,
            to: to,
            message: message,
            amount: amount
        }));
        emit Deposit();
    }


    function firstLiquidity(uint256 tokens) external payable onlyOwner {
        require(firstLiquidityEnabled, "Presale isn't enabled");
        firstLiquidityEnabled = false;
        addLiquidityBNB(tokens, msg.value);
        emit FirstLiquidityAdded(msg.value);
    }

    function sendTokens(address token, address _to, uint256 _amount) private {
        IERC20 token = IERC20(address(token));
        token.transfer(_to, _amount);
    }

    function swapAndAddLiquidity() private {
        uint256 contractBalance = address(this).balance;
        swapTokensForBNB(_poolLiquidity);
        uint256 liquidityTokens = balanceOf(address(this)).mul(10).div(100);
        addLiquidityBNB(liquidityTokens, contractBalance);
        _poolLiquidity = 0;
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2RouterBNB.WETH();

        _approve(address(this), address(uniswapV2RouterBNB), tokenAmount);

        uniswapV2RouterBNB.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
    function swapTokensForBUSD(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2RouterBNB.WETH();

        _approve(address(this), address(uniswapV2RouterBNB), tokenAmount);

        uniswapV2RouterBNB.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function teamPayment() external onlyOwner {
        super._transfer(address(this), addressHeisenDev, _poolHeisenDev);
        super._transfer(address(this), addressMarketing, _poolMarketing);
        super._transfer(address(this), addressTeam, _poolTeam);
        uint256 amount = _poolHeisenDev + _poolMarketing + _poolTeam;
        _poolHeisenDev = 0;
        _poolMarketing = 0;
        _poolTeam = 0;
        (bool sent, ) = addressHeisenDev.call{value: address(this).balance}("");
        require(sent, "Failed to send BNB");
        emit TeamPayment(amount);
    }

    function updateTaxesFees(uint256 _heisenDevTaxFee, uint256 _marketingTaxFee, uint256 _teamTaxFee, uint256 _liquidityTaxFee) private {
        taxFeeHeisenDev = _heisenDevTaxFee;
        taxFeeMarketing = _marketingTaxFee;
        taxFeeTeam = _teamTaxFee;
        taxFeeLiquidity = _liquidityTaxFee;
        emit UpdateTaxesFees(_heisenDevTaxFee, _marketingTaxFee, _teamTaxFee, _liquidityTaxFee);
    }

    function updateWithdrawOptions(uint256 _withdrawPrice) private {
        withdrawPrice = _withdrawPrice;
        emit UpdateWithdrawOptions(_withdrawPrice);
    }

    function withdraw() external payable {
        require(msg.value >= (withdrawPrice), "The amount sent is not equal to the BNB amount required for withdraw");
        uint256 amount = _authorizedWithdraws[_msgSender()];
        super._transfer(address(this), _msgSender(), amount);
        _authorizedWithdraws[_msgSender()] = 0;
        emit Withdraw(amount);
    }
}
