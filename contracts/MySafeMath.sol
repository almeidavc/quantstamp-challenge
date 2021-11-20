pragma solidity 0.7.0;

library MySafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 res) = tryAdd(a, b);
        
        if (!success) {
            revert();
        }
        
        return res;
    }
   
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 res) = trySub(a, b);
        
        if (!success) {
            revert();
        }
        
        return res;
    }
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 res) = tryMul(a, b);
        
        if (!success) {
            revert();
        }
        
        return res;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        (bool success, uint256 res) = tryDiv(a, b);
        
        if (!success) {
            revert();
        }
        
        return res;
    }
    
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }
}