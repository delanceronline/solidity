pragma solidity 0.5.16;

import './BEP20/IBEP20.sol';
import './BEP20/Ownable.sol';

import "./math/SafeMath.sol";
import './Model.sol';
import './StableCoin.sol';
import './OrderEscrow.sol';

contract Token is Context, IBEP20, Ownable {
  using SafeMath for uint256;
  
  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  
  uint256 private _totalSupply;
  uint8 private _decimals;
  string private _symbol;
  string private _name;

  address public modelAddress;

  uint256 public scaling = uint256(10) ** 6;
  mapping(address => uint256) public scaledDividendBalanceOf;
  uint256 public scaledDividendPerToken;
  mapping(address => uint256) public scaledDividendCreditedTo;
  uint256 public scaledRemainder = 0;
  uint256 public circulationTotal = 0;

  modifier tokenEscrowOnly()
  {
    if(msg.sender == Model(modelAddress).tokenEscrowAddress()) _;
  }

  modifier orderEscrowOnly()
  {
    if(msg.sender == Model(modelAddress).orderEscrowAddress()) _;
  }

  modifier dividendPoolOnly()
  {
    if(msg.sender == Model(modelAddress).dividendPoolAddress()) _;
  }

  constructor(address addr) public {

    _name = "DELANCER";
    _symbol = "DELA";
    _decimals = 18;
    _totalSupply = 10000 * (uint256(10) ** _decimals);
    _balances[msg.sender] = _totalSupply;

    modelAddress = addr;

    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  function withdrawDividend(address account) external dividendPoolOnly returns (uint)
  {
    
    if(account != Model(modelAddress).tokenEscrowAddress())
    {
      update(account);
      uint256 amount = scaledDividendBalanceOf[account].div(scaling);
      scaledDividendBalanceOf[account] = scaledDividendBalanceOf[account].mod(scaling);  // retain the remainder

      return amount;
    }

    return 0;
  }

  function adjustCirculationTotal(uint amount) external tokenEscrowOnly{

    require(amount > 0);

    if(circulationTotal > 0)
    {
      circulationTotal = circulationTotal.add(amount);
    }
    else
    {
      circulationTotal = amount;

      //uint orderEscrowBalance = StableCoin(Model(modelAddress).stableCoinAddress()).balanceOf(Model(modelAddress).orderEscrowAddress());
      //if(orderEscrowBalance > 0)

      uint dividendPoolBalance = StableCoin(Model(modelAddress).stableCoinAddress()).balanceOf(Model(modelAddress).dividendPoolAddress());
      if(dividendPoolBalance > 0)
      {
        uint256 available = (dividendPoolBalance.mul(scaling)).add(scaledRemainder);
        scaledDividendPerToken = scaledDividendPerToken.add(available.div(circulationTotal));
        scaledRemainder = available.mod(circulationTotal);
      }
    }
    
  }

  function dividendBalanceOf(address owner) external view returns (uint)
  {
    uint amount = 0;

    if(owner != Model(modelAddress).tokenEscrowAddress())
    {
      uint256 owed = scaledDividendPerToken.sub(scaledDividendCreditedTo[owner]);
      amount = (scaledDividendBalanceOf[owner].add(_balances[owner].mul(owed))).div(scaling);
    }

    return amount;
  }

  function update(address account) internal {

    uint256 owed = scaledDividendPerToken.sub(scaledDividendCreditedTo[account]);
    scaledDividendBalanceOf[account] = scaledDividendBalanceOf[account].add(_balances[account].mul(owed));
    scaledDividendCreditedTo[account] = scaledDividendPerToken;    

  }

  /**
   * @dev Moves tokens `amount` from `sender` to `recipient`.
   *
   * This is internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
  function _transfer(address sender, address recipient, uint256 amount) internal {
    
    require(amount <= _balances[sender]);

    address tokenEscrowAddress = Model(modelAddress).tokenEscrowAddress();

    if(recipient != tokenEscrowAddress)
    {
      if(sender != tokenEscrowAddress)
        update(sender);

      update(recipient);

      _balances[sender] -= amount;
      _balances[recipient] += amount;
      emit Transfer(sender, recipient, amount);
    }

  }

  function updatePoolInflow(uint inflowAmount) external orderEscrowOnly 
  {
    uint256 available = (inflowAmount.mul(scaling)).add(scaledRemainder);

    if(circulationTotal > 0)
    {
      scaledDividendPerToken = scaledDividendPerToken.add(available.div(circulationTotal));
      scaledRemainder = available.mod(circulationTotal);
    }
  }

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() external view returns (address) {
    return owner();
  }

  /**
   * @dev Returns the token decimals.
   */
  function decimals() external view returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Returns the token symbol.
   */
  function symbol() external view returns (string memory) {
    return _symbol;
  }

  /**
  * @dev Returns the token name.
  */
  function name() external view returns (string memory) {
    return _name;
  }

  /**
   * @dev See {BEP20-totalSupply}.
   */
  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {BEP20-balanceOf}.
   */
  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) external returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev See {BEP20-allowance}.
   */
  function allowance(address owner, address spender) external view returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) external returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev See {BEP20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {BEP20};
   *
   * Requirements:
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for `sender`'s tokens of at least
   * `amount`.
   */
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }  

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
   *
   * This is internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
