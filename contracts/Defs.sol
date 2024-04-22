// SPDX-License-Identifier: UNLICENSED
pragma solidity >= 0.8.0 <= 0.8.19;


// === Generic Constants ===============================================================================================

uint constant NOT_INDEXED = type(uint).max;

// === Currency ========================================================================================================

/**
 * @notice Solidity does not have any native type for representing an amount of money. In the fundraising campaign
 * contract these values will be represented as a fixed point signer integer plus a 16 bit currency code. For instance
 * EUR 530.55 will be stored as a triple 53055/2/978 where 2 is the scale and 978 the currency ISO code (some of them
 * defined below). Similarly BTC 1 is stored in SATs 100,000,000/8/1999 and ETH 0.001 will be 1e15/18/2000
 *
 * https://www.iso.org/iso-4217-currency-codes.html
 * https://www.six-group.com/en/products-services/financial-information/data-standards.html
 */

type Currency is int16;

Currency constant CHF = Currency.wrap(756); // scale 100
Currency constant EUR = Currency.wrap(978); // scale 100
Currency constant GBP = Currency.wrap(826); // scale 100
Currency constant JPY = Currency.wrap(392); // scale 1
Currency constant USD = Currency.wrap(840); // scale 100
Currency constant CNY = Currency.wrap(156); // scale 100
Currency constant XAG = Currency.wrap(961); // scale 1
Currency constant XAU = Currency.wrap(959); // scale 1

// BTC is legal tender in some countries but it doesn't have a ISO standard symbol. BTC 1 is SAT 1e8.
Currency constant XBT = Currency.wrap(1999); // scale 1e8

// Ethereum currency, ETH 1 is WEI 1e18.
Currency constant ETH = Currency.wrap(2000); // scale 1e18

/**
 * @dev Internal use, the function returns the bare code of the given currency.
 */

function code( Currency cur ) pure returns (int16) {
    return Currency.unwrap(cur);
}


// === CampaignDetails =================================================================================================

/**
 * @notice This structure collects all the relevant details od a fundraising campaign. The details of a campaign can be
 * updated until the first donation is registered, then these details are locked forever.
 */

struct CampaignDetails {

    /**
     * @notice Unique identifier of a campaign as specified in the database. The original id is a number stored in a
     * varchar(70) data type. A int256 can store numbers with over 70 decimal digits.
     */

    int256 id;


    /**
     * @notice The topic of the campaign.
     */

    string topic;


    /**
     * @notice  The promoting institution of the fundraising campaign.
     */

    string promoter;


    /**
     * @notice Duration of the campaign, expressed with a start and an end date. Date and time in Solidity are stored as
     * simple timestamps of type uint256. The keyword "now" will return the Unix timestamp of the latest block, namely
     * the number of seconds that have been passed since January 1st 1970.
     */


    uint256 start;
    uint256 end;


    /**
     * @notice Goal the fundraising campaign expressed in a specific currency. The number is multiplied by the
     * CURRENCY_SCALE constant in order to represent fractional digits.
     */

    int256 goal;


    /**
     * @notice Numeric currency code chosen for this fundraising campaign. See currency codes definition.
     */

    int16 currencyCode;


    /**
     * @notice Any amount of money described in a campaign is stored as a fixed point number, where the length of the
     * fractional part is given by the currency scale. For instance if the goal is USD 200,500.999 the number is stored
     * as 200500999 / 10^S where S is the currency scale.
     */

    int8 currencyScale;
}


// === Donation ========================================================================================================

/**
 * @notice This structure captures the essential data of a donation for a given fundraising campaign. Its main goals are
 * uniquely identify the donor and track the donation.
 */

struct Donation {

    /**
     * @notice Numeric unique identifier of a donation, this is derived from an external database.
     */

    int256 id;


    /**
     * @notice The update number of this donation. A donation cannot be deleted or removed but it can be updated
     * multiple times for correcting errors, until the maximum number of updates is reached.
     */

    uint16 update;


    /**
     * @notice When the donation was made. This is a basic Unix timestamp, namely the number of seconds that have been
     * passed since January 1st 1970.
     */

    uint256 when;


    /**
     * @notice The amount of this donation. This number shall be interpreted using the currency and scale defined by the
     * related campaign contract. Currency scale and code are implicit, every donation amount shall be converted to
     * match the currency scale and code of the related campaign.
     */

    int256 amount;


    /**
     * @notice Numeric unique identifier of the donor, this is derived from an external database.
     */

    int64 donorId;


    /**
     * @notice donorCode is the external identifier of a donor, it can be a VAT number a TAX code or similar.
     */

    string donorCode;


    /**
     * @notice donorName is the generic name of the donor. It can be the complete name of a person or the name of an
     * organization.
     */

    string donorName;


    /**
     * Restoration part data.
     *
     * TODO: missing description.
     */

    int32 partId;
    string partName;
    int32[] partUnits;
}




