// SPDX-License-Identifier:GPL-3.0

pragma solidity 0.6.12;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract SecondBlock is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _blacklist;

    uint256 private _totalSupply;
    string private _symbol;
    string private _tokenname;
    uint8 private _decimals;
    uint private _icoRate = 100; //  BSC : SBT = 100 : 1
    uint private _feeRate = 1;   //  Burn 1%
    address private _admin;
    address payable _this;
    bool private _start; 

    event Burn(address _addr,address _blackhole,uint256 _amount);
    event Buy(address _addr,uint256 _amount);
    
    constructor () public {
        _symbol = "SBT";
        _tokenname = "Second Block";
        _totalSupply = 1000*1e8*1e18;
        _decimals = 18;
        _balances[address(this)] = _totalSupply * 10 / 100;                              // ICO
        _balances[0x0C80cdFfE28Cd023Bf2b549a118C3F4f02eA770A] = _totalSupply * 90 / 100; // Owner holder

        _start = false;  // No Burn at the beginning
        _admin = msg.sender;
        emit Transfer(address(0), 0x0C80cdFfE28Cd023Bf2b549a118C3F4f02eA770A, _totalSupply * 90 / 100 );
    }

    modifier onlyOwner() {
        require(_admin == msg.sender, "Ownable: You are not the owner");
        _;
    }

    function withdrawICO() public onlyOwner {
        _this = msg.sender;
        uint256 _amount = address(this).balance;
        _this.transfer(_amount);
    }

    function name() public view returns (string memory) {
        return _tokenname;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function burncoin (uint256 amount) external  {
        require(_balances[_msgSender()]>=amount,"Error : The amount destroyed cannot be greater than the amount held");
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        emit Transfer(_msgSender(),address(0),amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(!_blacklist[msg.sender],"ERC20 : You are locked out");
        if (_start) {
            uint256 _amount = amount.mul(uint256(100).sub(_feeRate)).div(100);  
            uint256 _fee = amount.sub(_amount);
            _transfer(_msgSender(), recipient, _amount);
            emit Burn(_msgSender(),address(0),_fee);
            return true;
        }
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function setBlackList(address _addr,bool locked) external onlyOwner {
        _blacklist[_addr] = locked;
    }    

    function setICORate(uint256 _num) external onlyOwner {
        _icoRate = _num;
    }

    function setFeeRate(uint256 _num) external onlyOwner {
       _feeRate = _num;
    }
    
    function setStart(bool _status) external onlyOwner {
       _start = _status;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(!_blacklist[msg.sender],"ERC20 : You are locked out");

        if (_start) {
            uint256 _amount = amount.mul(100 - _feeRate).div(100);
            uint256 _fee = amount.sub(_amount);
            _transfer(_msgSender(), recipient, _amount);
            _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
            emit Burn(_msgSender(),address(0),_fee);
            return true;
        }

        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    receive () external payable {
        uint256 _amount = msg.value;
        _transfer(address(this),msg.sender,_amount.mul(_icoRate));
        emit Buy(msg.sender,_amount.mul(_icoRate));
    }

}
