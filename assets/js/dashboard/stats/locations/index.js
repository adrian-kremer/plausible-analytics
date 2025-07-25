import React from 'react'

import * as storage from '../../util/storage'
import CountriesMap from './map'

import * as api from '../../api'
import { apiPath } from '../../util/url'
import ListReport from '../reports/list'
import * as metrics from '../reports/metrics'
import {
  hasConversionGoalFilter,
  getFiltersByKeyPrefix
} from '../../util/filters'
import ImportedQueryUnsupportedWarning from '../imported-query-unsupported-warning'
import { citiesRoute, countriesRoute, regionsRoute } from '../../router'
import { useQueryContext } from '../../query-context'
import { useSiteContext } from '../../site-context'
import { TabButton, TabWrapper } from '../../components/tabs'

function Countries({ query, site, onClick, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/countries'), query, { limit: 9 })
  }

  function renderIcon(country) {
    return <span className="mr-2">{country.flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'country',
      filter: ['is', 'country', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      onClick={onClick}
      keyLabel="Country"
      metrics={chooseMetrics()}
      detailsLinkProps={{
        path: countriesRoute.path,
        search: (search) => search
      }}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}

function Regions({ query, site, onClick, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/regions'), query, { limit: 9 })
  }

  function renderIcon(region) {
    return <span className="mr-2">{region.country_flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'region',
      filter: ['is', 'region', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      onClick={onClick}
      keyLabel="Region"
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: regionsRoute.path, search: (search) => search }}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}

function Cities({ query, site, afterFetchData }) {
  function fetchData() {
    return api.get(apiPath(site, '/cities'), query, { limit: 9 })
  }

  function renderIcon(city) {
    return <span className="mr-2">{city.country_flag}</span>
  }

  function getFilterInfo(listItem) {
    return {
      prefix: 'city',
      filter: ['is', 'city', [listItem['code']]],
      labels: { [listItem['code']]: listItem['name'] }
    }
  }

  function chooseMetrics() {
    return [
      metrics.createVisitors({ meta: { plot: true } }),
      hasConversionGoalFilter(query) && metrics.createConversionRate()
    ].filter((metric) => !!metric)
  }

  return (
    <ListReport
      fetchData={fetchData}
      afterFetchData={afterFetchData}
      getFilterInfo={getFilterInfo}
      keyLabel="City"
      metrics={chooseMetrics()}
      detailsLinkProps={{ path: citiesRoute.path, search: (search) => search }}
      renderIcon={renderIcon}
      color="bg-orange-50"
    />
  )
}

const labelFor = {
  countries: 'Länder',
  regions: 'Regionen',
  cities: 'Städte'
}

class Locations extends React.Component {
  constructor(props) {
    super(props)
    this.onCountryFilter = this.onCountryFilter.bind(this)
    this.onRegionFilter = this.onRegionFilter.bind(this)
    this.afterFetchData = this.afterFetchData.bind(this)
    this.tabKey = `geoTab__${props.site.domain}`
    const storedTab = storage.getItem(this.tabKey)
    this.state = {
      mode: storedTab || 'map',
      loading: true,
      skipImportedReason: null
    }
  }

  componentDidUpdate(prevProps, prevState) {
    const isRemovingFilter = (filterName) => {
      return (
        getFiltersByKeyPrefix(prevProps.query, filterName).length > 0 &&
        getFiltersByKeyPrefix(this.props.query, filterName).length == 0
      )
    }

    if (this.state.mode === 'cities' && isRemovingFilter('region')) {
      this.setMode('regions')()
    }

    if (this.state.mode === 'regions' && isRemovingFilter('country')) {
      this.setMode(this.countriesRestoreMode || 'countries')()
    }

    if (
      this.props.query !== prevProps.query ||
      this.state.mode !== prevState.mode
    ) {
      this.setState({ loading: true })
    }
  }

  setMode(mode) {
    return () => {
      storage.setItem(this.tabKey, mode)
      this.setState({ mode })
    }
  }

  onCountryFilter(mode) {
    return () => {
      this.countriesRestoreMode = mode
      this.setMode('regions')()
    }
  }

  onRegionFilter() {
    this.setMode('cities')()
  }

  afterFetchData(apiResponse) {
    this.setState({
      loading: false,
      skipImportedReason: apiResponse.skip_imported_reason
    })
  }

  renderContent() {
    switch (this.state.mode) {
      case 'cities':
        return (
          <Cities
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'regions':
        return (
          <Regions
            onClick={this.onRegionFilter}
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'countries':
        return (
          <Countries
            onClick={this.onCountryFilter('countries')}
            site={this.props.site}
            query={this.props.query}
            afterFetchData={this.afterFetchData}
          />
        )
      case 'map':
      default:
        return (
          <CountriesMap
            onCountrySelect={this.onCountryFilter('map')}
            afterFetchData={this.afterFetchData}
          />
        )
    }
  }

  render() {
    return (
      <div>
        <div className="w-full flex justify-between">
          <div className="flex gap-x-1">
            <h3 className="font-bold dark:text-gray-100">
              {labelFor[this.state.mode] || 'Standorte'}
            </h3>
            <ImportedQueryUnsupportedWarning
              loading={this.state.loading}
              skipImportedReason={this.state.skipImportedReason}
            />
          </div>
          <TabWrapper>
            {[
              { label: 'Karte', value: 'map' },
              { label: 'Länder', value: 'countries' },
              { label: 'Regionen', value: 'regions' },
              { label: 'Städte', value: 'cities' }
            ].map(({ value, label }) => (
              <TabButton
                key={value}
                onClick={this.setMode(value)}
                active={this.state.mode === value}
              >
                {label}
              </TabButton>
            ))}
          </TabWrapper>
        </div>
        {this.renderContent()}
      </div>
    )
  }
}

function LocationsWithContext() {
  const { query } = useQueryContext()
  const site = useSiteContext()
  return <Locations site={site} query={query} />
}
export default LocationsWithContext
