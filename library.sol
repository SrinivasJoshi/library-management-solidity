// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract Library is ReentrancyGuard{
    struct Book 
    {
        string title;
        string author;
        uint256 inventory;
        bool isAvailable;
    }

    mapping(uint256 => Book) public books;
    mapping(address => mapping(uint256 => bool)) public borrowed;
    mapping(address => mapping(uint256 => bool)) public bookReturnRequested;
    uint256 public numBooks;
    uint256 public tokenAmount;
    address public admin;
    address[] public librarians;
    mapping(address => bool) public librarianExists;
    IERC20 public dai;

    event BookAdded(string title, string author, uint256 inventory);
    event BookBorrowed(uint256 bookId, address user);
    event LibrarianAdded(address librarian);
    event BookReturnApprovalRequested(uint256 bookId, address user);
    event BookReturnApproved(uint256 bookId, address librarian);
    event BookReturnDenied(uint256 bookId, address librarian);
    event BookReturned(uint256 bookId, address user);

    constructor(IERC20 _dai, uint256 _tokenAmount) {
        dai = _dai;
        tokenAmount = _tokenAmount;
        admin=msg.sender;
    }

    modifier onlyAdmin(){
        require(msg.sender == admin,"Only an admin can perform this action");
        _;
    }

    modifier onlyLibrarian() {
        require(librarianExists[msg.sender], "Only a librarian can perform this action");
        _;
    }
    modifier bookIdExists(uint256 _bookId) {
        require(_bookId < numBooks, "This book ID does not exist");
        _;
    }

    function addBook(string memory _title, string memory _author, uint256 _inventory) public onlyLibrarian {
        for (uint256 i = 0; i < numBooks; i++) {
            if (keccak256(bytes(books[i].title)) == keccak256(bytes(_title)) &&
                keccak256(bytes(books[i].author)) == keccak256(bytes(_author))) {
                // If a book with the same title and author already exists, increase its inventory
                books[i].inventory += _inventory;
                books[i].isAvailable = true;
                emit BookAdded(_title, _author, _inventory);
                return;
            }
        }
        // If a book with the same title and author does not exist, add a new book
        books[numBooks] = Book(_title, _author, _inventory, true);
        emit BookAdded(_title, _author, _inventory);
        numBooks++;
    }

    function borrowBook(uint256 _bookId) public bookIdExists(_bookId) nonReentrant{
        require(books[_bookId].isAvailable, "This book is not available");
        require(!borrowed[msg.sender][_bookId], "You have already borrowed this book");
        require(dai.balanceOf(msg.sender) >= tokenAmount, "You do not have enough DAI to borrow a book");
        require(dai.allowance(msg.sender, address(this)) >= tokenAmount, "You must approve DAI to borrow a book");
        
        dai.transferFrom(msg.sender, address(this), tokenAmount);
        borrowed[msg.sender][_bookId] = true;
        books[_bookId].inventory--;
        if(books[_bookId].inventory == 0) {
            books[_bookId].isAvailable = false;
        }
        emit BookBorrowed(_bookId, msg.sender);
    }

    function requestApproval(uint256 _bookId) public bookIdExists(_bookId){
        require(borrowed[msg.sender][_bookId], "You have not borrowed this book");
        bookReturnRequested[msg.sender][_bookId] = true;
        emit BookReturnApprovalRequested(_bookId,msg.sender);
    }

    function approvalFromLibrarian(uint256 _bookId,address _user,bool _approved) public bookIdExists(_bookId) onlyLibrarian {
        require(bookReturnRequested[_user][_bookId], "No approval needed for this book");
        // if book in good condition 
        if(_approved){
            bookReturnRequested[_user][_bookId] = false;
            emit BookReturnApproved(_bookId,msg.sender);
            returnBook(_bookId,_user);
        }
        // if book in bad condition
        else{
            bookReturnRequested[_user][_bookId] = false;
            emit BookReturnDenied(_bookId,msg.sender);
        }
}

    function returnBook(uint256 _bookId,address _user) internal bookIdExists(_bookId){
        require(borrowed[_user][_bookId], "You have not borrowed this book");
        borrowed[_user][_bookId] = false;
        books[_bookId].inventory++;
        if(books[_bookId].inventory > 0) {
            books[_bookId].isAvailable = true;
        }
         dai.transfer(_user, tokenAmount);
        emit BookReturned(_bookId, _user);
    }

    function addLibrarian(address _newLibrarian) public onlyAdmin{
        require(!librarianExists[_newLibrarian], "This address is already a librarian");
        librarians.push(_newLibrarian);
        librarianExists[_newLibrarian] = true;
        emit LibrarianAdded(_newLibrarian);
    }

}

// - admin should only be able to withdraw interest part(if invested)
// - time of return and penalty
