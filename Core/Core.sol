// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./Ownable.sol";
import "./IERC20.sol";
import "./IMyNFT.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";
import "./Address.sol";

contract Core is Context, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _verifier;

    IERC20 private ERC20Contract;
    IERC20 private stableToken;
    MyNFT private mainContract;

    uint8 private percentBurn = 10;
    uint8 private percentTransfer = 90;

    address private receiverWallet = 0x3fD8B95f2dB23B17C4c2275E04A73803390f1482;

    mapping(uint256 => bool) private usedNonces;

    event ItemBought(address indexed buyer, uint256 _nftId, uint256 _amount, string args);
    event MultiItemBought(address indexed buyer, uint256[] _nftId, uint256 _amount, string args);

    constructor(address cOwner, address verifier) Ownable(cOwner) {
        require(cOwner != address(0), "Zero address for owner");
        require(verifier != address(0), "Zero address for verifier");

        _verifier = verifier;
    }

    function setStableToken(address _stableToken) external onlyOwner {
        require(_stableToken != address(0), "Stable token contract zero address");

        stableToken = IERC20(_stableToken);
    } 

    function setERC20Contract(address _ERC20Contract) external onlyOwner {
        require(_ERC20Contract != address(0), "Stable token contract zero address");

        ERC20Contract = IERC20(_ERC20Contract);
    } 

    function setMainNFT(address _contract) external onlyOwner {
        require(_contract != address(0), "Zero address for NFT contract is not acceptable");
        mainContract = MyNFT(_contract);
    }

    function buyItem(int8 _currToken, uint256 _amount, int8 _mode, uint256 nonce, bytes memory sig, string memory _args) external {
        require(_amount > 0, "Token amount cannot be zero");

        address addressToken = address(0);

        if (_currToken == 0) {
            require(address(stableToken) != address(0), "Not set stable token contract");
            require(stableToken.balanceOf(_msgSender()) >= _amount,"Insufficient ERC20 tokens amount to buy");
            require(stableToken.allowance(_msgSender(), address(this)) >= _amount, "Amount is not allowed by ERC20 holder");
            addressToken = address(stableToken);
        } else {            
            require(address(ERC20Contract) != address(0), "Not set stable token contract");
            require(ERC20Contract.balanceOf(_msgSender()) >= _amount,"Insufficient ERC20 tokens amount to buy");
            require(ERC20Contract.allowance(_msgSender(), address(this)) >= _amount, "Amount is not allowed by ERC20 holder");
            addressToken = address(ERC20Contract);
        }

        require(!usedNonces[nonce]);
        bytes32 message = prefixed(keccak256(abi.encodePacked(_currToken, _amount, _mode, nonce, addressToken, _args)));
        address signer = recoverSigner(message, sig);
        require(signer ==_verifier, "Unauthorized transaction");
        usedNonces[nonce] = true;

        if (_currToken == 0) {
            buyFromStableToken(_amount, _mode, _args);
        } else {
            buyFromErc20(_amount, _mode, _args);
        }
    }
    
    function setShare(uint8 _percentBurn, uint8 _percentTransfer) external onlyOwner {
        require(_percentBurn + _percentTransfer == 100, "Must be 100%");

        percentBurn = _percentBurn;
        percentTransfer = _percentTransfer;
    }

    function buyFromErc20(uint256 _amount, int8 _mode, string memory _args) private  {
        uint256 amountBurn = _amount.div(100).mul(percentBurn);
        uint256 amountTransfer = _amount.div(100).mul(percentTransfer);

        ERC20Contract.safeTransferFrom(_msgSender(), receiverWallet, amountTransfer);
        ERC20Contract.burnFrom(_msgSender(), amountBurn);

        if (_mode == 0) {
            uint256 result = mainContract.createFromERC20(_msgSender());
            emit ItemBought(_msgSender(), result, _amount, _args);
        } else {
            emit ItemBought(_msgSender(), 0, _amount, _args);
        }
    }

    function buyFromStableToken(uint256 _amount, int8 _mode, string memory _args) private  {
        stableToken.safeTransferFrom(_msgSender(), receiverWallet, _amount);

        if (_mode == 0) {
            uint256 result = mainContract.createFromERC20(_msgSender());
            emit ItemBought(_msgSender(), result, _amount, _args);
        } else {
            emit ItemBought(_msgSender(), 0, _amount, _args);
        }
    }

    function multiBuyItem(int8 _currToken, uint256 _count, uint256 _amount, uint256 nonce, bytes memory sig, string memory _args) external {
        require(_amount > 0, "Token amount cannot be zero");
        require(_count > 0, "Token count cannot be zero");

        address addressToken = address(0);

        if (_currToken == 0) {
            require(address(stableToken) != address(0), "Not set stable token contract");
            require(stableToken.balanceOf(_msgSender()) >= _amount,"Insufficient ERC20 tokens amount to buy");
            require(stableToken.allowance(_msgSender(), address(this)) >= _amount, "Amount is not allowed by ERC20 holder");
            addressToken = address(stableToken);
        } else {            
            require(address(ERC20Contract) != address(0), "Not set stable token contract");
            require(ERC20Contract.balanceOf(_msgSender()) >= _amount,"Insufficient ERC20 tokens amount to buy");
            require(ERC20Contract.allowance(_msgSender(), address(this)) >= _amount, "Amount is not allowed by ERC20 holder");
            addressToken = address(ERC20Contract);
        }

        require(!usedNonces[nonce]);
        bytes32 message = prefixed(keccak256(abi.encodePacked(_currToken, _count, _amount, nonce, addressToken, _args)));
        address signer = recoverSigner(message, sig);
        require(signer ==_verifier, "Unauthorized transaction");
        usedNonces[nonce] = true;

        if (_currToken == 0) {
            multiBuyFromStableToken(_count, _amount, _args);
        } else {
            multiBuyFromErc20(_count, _amount, _args);
        }
    }

    function multiBuyFromErc20(uint256 _count, uint256 _amount, string memory _args) private  {
        uint256 amountBurn = _amount.div(100).mul(percentBurn);
        uint256 amountTransfer = _amount.div(100).mul(percentTransfer);

        ERC20Contract.safeTransferFrom(_msgSender(), receiverWallet, amountTransfer);
        ERC20Contract.burnFrom(_msgSender(), amountBurn);

        uint256[] memory result = mainContract.multiCreateFromERC20(_msgSender(), _count);
        emit MultiItemBought(_msgSender(), result, _amount, _args);       
    }

    function multiBuyFromStableToken(uint256 _count, uint256 _amount, string memory _args) private  {
        stableToken.safeTransferFrom(_msgSender(), receiverWallet, _amount);
        
        uint256[] memory result = mainContract.multiCreateFromERC20(_msgSender(), _count);
        emit MultiItemBought(_msgSender(), result, _amount, _args);      
    }

    function setVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "Zero address for verifier");
        _verifier = verifier;
    }

    function setReceiverWalet(address _receiverWallet) external onlyOwner {
        require(_receiverWallet != address(0), "Zero address for receiver wallet");

        receiverWallet = _receiverWallet;
    }

    function recoverSigner(bytes32 message, bytes memory sig) public pure
    returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);

        return ecrecover(message, v, r, s);
    }

    function splitSignature(bytes memory sig)
    public
    pure
    returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

}
