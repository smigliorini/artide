// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0 <= 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

// [WARNING] The Solidity 0.8.x compiler has new built-in overflow checks that make the SafeMath library obsolete most
// of the time. Anyway, the latest versions of SafeMath cannot be used with the older versions of the language.
// Many implicit checks, but not all, can be disabled by wrapping the code inside an unchecked{ ... } block.
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Campaign.sol";





/**
 * @title Agency contract
 *
 * @notice TODO
 */

contract Agency is Ownable {

    // Solidity 0.8.x compiler has new built-in overflow checks that make the SafeMath library not necessary most of the
    // time. Many implicit checks, but not all, can be disabled by wrapping the code inside an unchecked { ... } block.
    // using SafeMath for int256;


    /**
     * @notice The right values for these constants shall be derived from the implemented methods. If the execution of a
     * method depends on the number of items stored, it can reach a point where the gas needed is too high to terminate,
     * for instance because it is greater than the block gas limit. In these cases the contract may get stuck in an
     * unwanted failure state.
     */

    int constant public MAX_ACTIVE_CAMPAIGNS = type(int).max;

    int constant public MAX_SELECT_LIMIT = 32;

    /**
     * @notice This event is fired when a new campaign is created.
     */

    event NewCampaignEvent( Agency agency, Campaign indexed campaign );

    event ArchivedCampaignEvent(  Agency agency, Campaign indexed campaign, uint previousIndex );

    /**
     * @notice This error is raised when one attempts to create a new campaign but there is no more storage available.
     */

    error TooManyActiveCampaignsError(uint actualCampaigns);


    /**
     * @notice This error is raised if the specified campaign identifier is already in use.
     */

    error DuplicatedCampaignError(int campaignId);

    error IllegalOffsetLimitError( int offset, int limit );

    error CampaignNotFoundError( int campaignId );

    error AlreadyArchivedCampaignError( int campaignId );

    error TotalOverflowError(int total );

    /**
    * @dev This type is used internally for reducing the chances of a silent conversion error.
     */

    type CampaignHandle is int;

    function handleCampaign(int i) private pure returns (CampaignHandle) {
        return CampaignHandle.wrap(i);
    }

    function ordinal(CampaignHandle c)  private pure returns (int) {
        return CampaignHandle.unwrap(c);
    }


    /**
     * @notice This contract maintains a mapping of all launched fundraising campaigns, the campaigns will never be
     * removed from this data structure.
     */

    mapping(CampaignHandle => Campaign) private _campaigns;


    /**
     * @notice This contract also maintains a list of the active campaigns, this is necessary because a mapping is not
     * enumerable and the agency may want to know what are the active campaigns. A campaign stops to be active when it
     * is archived, and when it is archived it will be removed from this list. An archived campaign contract instance
     * will continue to exists and so the related donations but will not be directly reachable from this agency. This
     * semantics is desired because a certificate for a donation will be permanently available on the blockchain
     * regardless of the issuing agency. At the same time, an agency may require to archive some fundraising campaigns
     * to keep the contract manageable.
     */

    Campaign[] private _active;


    /**
     * @notice This variable maintains the total number of campaigns created from the deployment of this contract.
     */

    int private _total = 0;


    /**
     * @dev Solidity does not support any concept of "friend" contracts. This variable make sure that the function
     * updateIndex() of Campaign can be invoked only in the right context.
     */

    bool private _updateIndexEnabled = false;

    function isUpdateIndexEnabled() public view returns (bool) {
        return _updateIndexEnabled;
    }



    /**
     * @notice Contract constructor, nothing special happens here.
     */

    constructor(){
    }

    /**
     * @notice The method create a new campaign instance starting from the details specified as argument. The campaign
     * identifier attribute shall be a new unique identifier among the ones stored in the blockchain by this agency that
     * includes both, active and archived campaigns.
     */

    function createCampaign(CampaignDetails memory details) public onlyOwner returns (Campaign) {

        // These are very rare conditions that will never happens in any real scenario and it can be reasonable to
        // rely on implicit Solidity overflow checks. Nevertheless, in this way they are better documented and ready
        // to use in case the contract
        if( _total >= type(int).max ) {
            revert TotalOverflowError(_total);
        }
        if (_active.length >= uint(MAX_ACTIVE_CAMPAIGNS)) {
            revert TooManyActiveCampaignsError(_active.length);
        }

        CampaignHandle h = handleCampaign(details.id);
        /*if (_campaigns[h].exists()) {
            revert DuplicatedCampaignError(details.id);
        }//*/

        Campaign campaign = new Campaign(this, _active.length, details);

        _campaigns[h] = campaign;
        _active.push(campaign);
        _total = _total + 1;

        // Check invariants, removed for reducing contract size.
        // uint i = campaign.index();
        // assert( _actives[i].details().id == ordinal(h) );
        // assert( _campaigns[h].details().id == ordinal(h) );

        emit NewCampaignEvent( this, campaign );
        return campaign;
    }

    /**
      * @notice The method returns a tuple of three integers, the first element is the total number of campaign contract
      * instances created so far, the second the actual active campaigns and the last one the number of archived ones.
     */

    function countCampaigns() public view returns (int total, int active, int archived ) {
        // Safe conversion because length cannot be greater than MAX_ACTIVE_CAMPAIGNS.
        active = int(_active.length);
        return ( _total, active, _total -  active );
    }


    /**
     * TODO: comments.
     */

    function selectActiveCampaigns(int offset) public view returns (Campaign[] memory) {
        return selectActiveCampaigns(offset, MAX_SELECT_LIMIT);
    }


    /**
     * TODO: comments.
     */

    function selectActiveCampaigns(int offset, int limit) public view returns (Campaign[] memory selected) {

        int acts = int(_active.length);
        if( offset < 0 || offset >= acts || limit < 0 ) {
            revert IllegalOffsetLimitError( offset, limit );
        }

        int span;
        span = acts - offset;
        span = span < limit ? span : limit;
        span = span < MAX_SELECT_LIMIT ? span : MAX_SELECT_LIMIT;

        selected = new Campaign[](uint(span));
        uint k = uint(offset);
        for (uint i = 0; i < selected.length; i++) {
            selected[i] = _active[k + i];
        }

        return selected;
    }



    /**
     * TODO: comments.
     *
     * WARNING: the invocation of this method potentially change the campaigns ordering.
     */

    function archiveCampaign( int id, bool preserveOrdering ) public onlyOwner {

        Campaign r = _campaigns[handleCampaign(id)];
        if( !r.exists() ) {
            revert CampaignNotFoundError( id );
        }
        if ( r.isArchived() ) {
            revert AlreadyArchivedCampaignError( id );
        }

        _updateIndexEnabled = true;
        uint i = r.index();
        _active[i].updateIndex( NOT_INDEXED );

        if( !preserveOrdering ) {
            _active[i] = _active[_active.length - 1];
            _active[i].updateIndex( i );

        } else {
            for( uint j = i; j < _active.length - 1; j++ ) {
                _active[j] = _active[j + 1];
                _active[j].updateIndex( j );
            }
        }
        _updateIndexEnabled = false;

        _active.pop();
        emit ArchivedCampaignEvent( this, r, i );
    }



}
