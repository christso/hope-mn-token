pragma solidity ^0.4.11;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract HDMDToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public name = "HopeDiamond";
    string public symbol = "HDMD";
    uint public decimals = 8; // HDMD should have the same decimals as DMD
    string public version = "0.18";

    uint public totalSupply;
    uint public totalInitialSupply;
    uint public maxMint;

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    mapping(address => bool) allowedMinters;

    // This notifies clients about the amount burnt
    event Burn(address indexed burner, string dmdAddress, uint256 value);
    event Mint(address indexed _address, uint _reward);
    event Unmint(address indexed _address, uint _reward);

    /**
     * @dev Fix for the ERC20 short address attack.
     */
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    modifier onlyMinter() {
        require(allowedMinters[msg.sender]);
        _;
    }

    function HDMDToken() public {
        totalInitialSupply = 10000 * 10**decimals; // each masternode contains 10k DMDs

        balances[msg.sender] = totalInitialSupply;
        totalSupply = totalInitialSupply;
        maxMint = totalInitialSupply * 10;
    }

    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];
    }

    function burn(uint _value, string _dmdAddress) public returns (bool) {
        require(_value > 0);
        balances[msg.sender] = balances[msg.sender].sub(_value);  // Subtract from the sender
        totalSupply = totalSupply.sub(_value); // Updates totalSupply        
        Burn(msg.sender, _dmdAddress, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public onlyPayloadSize(3 * 32) returns (bool) {
        require(_to != address(0));
        var _allowance = allowed[_from][msg.sender];
        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require (_value <= _allowance);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = _allowance.sub(_value);
        Transfer(_from, _to, _value);

        return true;
    }

    // approve another account to transfer your tokens
    function approve(address _spender, uint256 _value) public returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        Approval(msg.sender, _spender, _value);
        return true;
    }

    // how much the spender can spend from the owner's address
    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function allowMinter(address _minter) onlyOwner public returns (bool) {
        allowedMinters[_minter] = true;
        return true;
    }
    
    function disallowMinter(address _minter) onlyOwner public returns (bool) {
        delete allowedMinters[_minter];
        return true;
    }

    function canMint(address _minter) public constant returns (bool) {
        return allowedMinters[_minter];
    }
    
    // modifies the total amount of coins in existance and gives the coins to the owner of the contract.
    function mint(uint256 _reward) onlyMinter public returns (bool) {
        if(_reward <= 0) return false;
        if(_reward > maxMint) return false;

        // increase total supply of coins in existence
        totalSupply = totalSupply.add(_reward);

        // new coins are sent to the owner, which also updates the mapping
        balances[owner] = balances[owner].add(_reward);

        Mint(msg.sender, _reward);
        return true;
    }

    function unmint(uint256 _reward) onlyMinter public returns (bool) {
        if(_reward <= 0) return false;

        // increase total supply of coins in existence
        totalSupply = totalSupply.sub(_reward);

        // new coins are sent to the owner, which also updates the mapping
        balances[owner] = balances[owner].sub(_reward);
        
        Unmint(msg.sender, _reward);
        return true;        
    }

    /* Batch token transfer. Used by contract creator to distribute initial and staked tokens to holders */
    function batchTransfer(address[] _recipients, uint[] _values) public onlyOwner returns (bool) {
        require( _recipients.length > 0 && _recipients.length == _values.length);

        uint total = 0;
        for (uint i = 0; i < _values.length; i++) {
            total = total.add(_values[i]);
        }

        for (uint j = 0; j < _recipients.length; j++) {
            balances[_recipients[j]] = balances[_recipients[j]].add(_values[j]);
            Transfer(msg.sender, _recipients[j], _values[j]);
        }

        balances[msg.sender] = balances[msg.sender].sub(total);
  
        return true;
    }
    
    /* Contract owner can transfer from any account so erroneous transactions can be easily reversed */
    function ownerTransfer(address _from, address _to, uint256 _value) public onlyOwner onlyPayloadSize(3 * 32) returns (bool) {
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    /* Contract owner can batch transfer back from multiple accounts */
    function reverseBatchTransfer(address[] _recipients, uint[] _values) public onlyOwner returns (bool) {
        require( _recipients.length > 0 && _recipients.length == _values.length);

        uint total = 0;
        for (uint i = 0; i < _values.length; i++) {
            total = total.add(_values[i]);
        }

        for (uint j = 0; j < _recipients.length; j++) {
            balances[_recipients[j]] = balances[_recipients[j]].sub(_values[j]);
            Transfer(_recipients[j], msg.sender, _values[j]);
        }

        balances[msg.sender] = balances[msg.sender].add(total);
  
        return true;        
    }
}