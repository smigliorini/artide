// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0 <= 0.8.19;

import "@openzeppelin/contracts/utils/Context.sol";
import "./Agency.sol";
import "./Defs.sol";

/**
 * @title The fundraising campaign contract.
 *
 * @notice An instance of this contract is created by the main agency for every fundraising campaign.
 */

contract Campaign is Context {

    // uint constant public NO_INDEX = type(uint).max;

    uint16 constant public DONATION_UPDATES_LIMIT = type(uint16).max;


    event NewDonationEvent(Campaign indexed campaign, Donation indexed donation);

    event UpdatedDonationEvent(Campaign indexed campaign, Donation indexed update);



    error CampaignMismatchError( int expectedCampaignId, int actualCampaignId );

    error LockedCampaignError( int numDonations );

    error DonationAlreadyExistsError( int donationId );

    error DonationNotFoundError( int donationId );

    error TooManyDonationUpdatesError(uint actualUpdates);


    /**
     * @dev This type is used internally for reducing the chances of a silent conversion error.
     */

    type DonationHandle is int;

    function handleDonation( int id ) private pure returns(DonationHandle) {
        return DonationHandle.wrap(id);
    }

    /**
     * @dev Internal use, check the related methods.
     */

    bool immutable private _exists;


    /**
     * @dev Internal use, check the related methods.
     */

    Agency immutable private _agency;

    uint private _index;

    CampaignDetails private _details;

    mapping(DonationHandle => Donation[] ) private _donations;

    int private _totalDonations;

    int private _totalFunds;


    /**
     * @notice Some methods can be invoked only by the agency that produces the fundraising campaign instance.
     */

    modifier onlyAgency() {
        require( _msgSender() == _agency.owner(), "Campaign: caller is not the agency owner" );
        _;
    }


    /**
     * The method initializes a new Campaign contract.
     *
     * @param agencyFactory The agency publishing this fundraising campaign. It shall be a valid Agency contract.
     *
     * @param newIndex New campaigns are tracked by the main agency contract.
     *
     * @param newDetails A structure containing the details of this new campaign. As long as a campaign has no donations
     * the details can be updated.
     */


    constructor( Agency agencyFactory, uint newIndex, CampaignDetails memory newDetails)  {
        require( agencyFactory != Agency(address(0)) );
        require( newIndex != NOT_INDEXED, "illegal campaign index" );

        _exists = true;
        _agency = agencyFactory;
        _index = newIndex;
        _details = newDetails;
        _totalDonations = 0;
        _totalFunds = 0;
    }


    /**
     * @notice The method returns true if this campaign exists, namely the constructor is called and the contract was
     * not deleted. Campaign contracts are stored in a native mapping data structure that is not enumerable and it
     * cannot contains null values. This method is used to distinguish real values from non existing or deleted ones.
     */

    function exists() public view returns(bool) {
        return _exists;
    }



    /**
     * @notice The method returns the agency contract of this campaign.
     */

    function agency() public view returns (Agency) {
        return _agency;
    }


    /**
     * TODO: notice The method returns the index of this campaign. If this campaign is archived, the method raises an error.
     */

    function index() public view returns (uint) {
        return _index;
    }


    /**
     * TODO
     */

    function updateIndex( uint i ) public onlyAgency {
        require( _agency.isUpdateIndexEnabled(),
            "Campaign: updateIndex() can be called only inside archiveCampaign()" );
        _index = i;
    }


    /**
     * @notice The method returns true if this campaign is active, false otherwise. In the last case the campaign is
     * said to be archived.
     */

    function isActive()  public view returns (bool) {
        return _index != NOT_INDEXED;
    }


    /**
     * @notice The method returns true if this campaign is archived, false otherwise. In the last case the campaign is
     * said to be active.
     */

    function isArchived()  public view returns (bool) {
        return _index == NOT_INDEXED;
    }


    /**
     * @notice The method checks if this fundraising campaign is locked, namely its details cannot be updated. An
     * instance of a campaign contract will become locked when the first donation is registered.
     *
     * @param locking -- The method returns true if this campaign is locked, false otherwise.
     */

    function isLocked() public view returns (bool locking) {
        return _totalDonations > 0;
    }


    /**
     * @notice The method returns the total number of unique donations registered under this campaign.
     */

    function totalDonations() public view returns (int) {
        return _totalDonations;
    }


    /**
     * @notice The method returns the total funds raised by the donations registered under this campaign.
     */

    function totalFunds() public view returns (int) {
        return _totalFunds;
    }


    /**
     * @notice The method allows an agency to update the details of this campaign, except for the main identifier. This
     * is a restricted method that only the related agency can invoke. The identifier attribute of the argument is not
     * ignored, it shall be the same of the existing identifier otherwise an error is thrown. Furthermore, the details
     * of a campaign can be updated only if there is no associated donations. If there is at least a donation, the
     * campaign is said to be locked and an error is raised. This constraint is in place for avoiding the falsification
     * of a campaign when the donations are already registered.
     *
     * @param newDetails A structure with the details of this campaign.
     */

    function updateDetails( CampaignDetails memory newDetails) public onlyAgency {
        if( newDetails.id != _details.id ) {
            revert CampaignMismatchError(_details.id, newDetails.id );
        }
        if( isLocked() ) {
            revert LockedCampaignError(_totalDonations);
        }
        _details = newDetails;
    }


    /**
     * @notice The method returns the details of this campaign.
     */

    function details() public view returns (CampaignDetails memory ) {
        return _details;
    }


    /**
     * @notice Register a new donation in this campaign. This is a restricted method that only the related agency can
     * invoke. If the donation is already registered the method reverts with an error. If this campaign is archived, no
     * further donations can be registered and the method raises an error.
     *
     * @param don -- A donation structure where the identifier shall be a valid identifier
     */

    function registerDonation( Donation memory don ) public onlyAgency {
        if( isArchived() ) {
            revert Agency.AlreadyArchivedCampaignError(_details.id);
        }
        DonationHandle i = handleDonation(don.id);
        if( _donations[i].length > 0 ) {
            revert DonationAlreadyExistsError(don.id);
        }
        _donations[i].push(don);
        _donations[i][0].update = 0;
        _totalDonations = _totalDonations + 1;
        _totalFunds = _totalFunds + _donations[i][0].amount;

        emit NewDonationEvent( this, _donations[i][0] );
    }


    /**
     * @notice The method updates the data of an already registered donation. This is a restricted method that only the
     * related agency can invoke. If the specified donation does not exist an error is raised. An error is also
     * triggered when the updating limit is reached.
     *
     * @param don -- A donation structure where the identifier shall be a valid identifier of an already registered
     * donation in this campaign. The argument will not be modified, also the update attribute is ignored.
     *
     * @return update -- If succeeded, the method returns the progressive number assigned to this update.
     */

    function updateDonation( Donation memory don ) public onlyAgency returns(uint16 update) {
        DonationHandle i = handleDonation(don.id);
        uint n = _donations[i].length;
        if( n == 0 ) {
            revert DonationNotFoundError(don.id);
        } else if( n >= DONATION_UPDATES_LIMIT) {
            revert TooManyDonationUpdatesError(n);
        }

        _donations[i].push(don);
        _donations[i][n].update = uint16(n);
        _totalFunds = _totalFunds - _donations[i][n-1].amount + _donations[i][n].amount;

        emit UpdatedDonationEvent( this, _donations[i][n] );

        return _donations[i][n].update;
    }


    /**
     * @notice The method retrieves the most up to date data of the specified donation. It raises an error if the
     * specified donation does not exists.
     *
     * @param id -- identifier of the desired donation.
     *
     * @return donation -- the retrieved donation.
     */

    function retrieveDonation( int id ) public view returns ( Donation memory donation ) {
        bool found;
        ( found, donation ) = findDonation( id );
        if( !found ) {
            revert DonationNotFoundError(id);
        }
        return donation;
    }


    /**
     * @notice The method finds if exists the last update of the specified donation in this fundraising campaign.
     *
     * @return found donation -- If the specified donation update exists, the method returns a pair where the
     * first element is true followed by the desired donation, otherwise it returns false and an empty donation
     * structure that can be ignored.
     */

    function findDonation( int id ) public view returns ( bool found, Donation memory donation ) {
        return findDonation( id, -1 );
    }


    /**
     * @notice The method finds if exists a specific donation update in this fundraising campaign.

     * @param id -- identifier of the desired donation.
     *
     * @param update -- the specific update of the desired donation. An update can be specified in two ways, with a non
     * negative integer starting from the original registration or a negative integer starting from the last update.
     * For instance, 0 is the original registration, 1 is the first update, whereas -1 is the last update and -2 is the
     * second last.
     *
     * @return found donation -- If the specified donation update exists, the method returns a pair where the
     * first element is true followed by the desired donation, otherwise it returns false and an empty donation
     * structure that can be ignored.
     */

    function findDonation( int id, int update ) public view returns ( bool found, Donation memory donation ) {

        DonationHandle i = handleDonation(id);
        int n = int(_donations[i].length);

        if( update < -n || update >= n ) {
            Donation memory r;
            return ( false, r );
        }
        // u >= -n => u + n >= 0 also
        // n <= LIMIT (2^16-1) => u < LIMIT => u + n < 2^32-1 well below int limits 2^255-1
        // no need to rely on overflow checks
        uint j = uint( (update + n) % n );
        return ( true, _donations[i][j] );
    }




}



