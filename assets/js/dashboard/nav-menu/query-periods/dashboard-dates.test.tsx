import React from 'react'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { TestContextProviders } from '../../../../test-utils/app-context-providers'
import { stringifySearch } from '../../util/url-search-params'
import { useNavigate } from 'react-router-dom'
import { getRouterBasepath } from '../../router'
import { DashboardPeriodPicker } from './dashboard-period-picker'
import { mockAnimationsApi, mockResizeObserver } from 'jsdom-testing-mocks'

mockAnimationsApi()
mockResizeObserver()

const domain = 'picking-dashboard-dates.test'
const periodStorageKey = `period__${domain}`

test('if no period is stored, loads with default value of "Last 28 days", all expected options are present', async () => {
  expect(localStorage.getItem(periodStorageKey)).toBe(null)
  render(<DashboardPeriodPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByText('Letzte 28 Tage'))

  expect(screen.getByTestId('datemenu')).toBeVisible()
  expect(screen.getAllByRole('link').map((el) => el.textContent)).toEqual(
    [
      ['Heute', 'D'],
      ['Gestern', 'E'],
      ['Echtzeit', 'R'],
      ['Letzte 24 Stunden', 'H'],
      ['Letzte 7 Tage', 'W'],
      ['Letzte 28 Tage', 'F'],
      ['Letzte 91 Tage', 'N'],
      ['Monat bis Heute', 'M'],
      ['Letzter Monat', 'P'],
      ['Jahr bis Heute', 'Y'],
      ['Letzte 12 Monate', 'L'],
      ['Gesamte Zeit', 'A'],
      ['Zeitraum', 'C'],
      ['Vergleichen', 'X']
    ].map((a) => a.join(''))
  )
})

test('user can select a new period and its value is stored', async () => {
  render(<DashboardPeriodPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  expect(screen.queryByTestId('datemenu')).toBeNull()
  await userEvent.click(screen.getByText('Letzte 28 Tage'))
  expect(screen.getByTestId('datemenu')).toBeVisible()
  await userEvent.click(screen.getByText('Gesamte Zeit'))
  expect(screen.queryByTestId('datemenu')).not.toBeInTheDocument()
  expect(localStorage.getItem(periodStorageKey)).toBe('all')
})

test('period "all" is respected, and Compare option is not present for it in menu', async () => {
  localStorage.setItem(periodStorageKey, 'all')

  render(<DashboardPeriodPicker />, {
    wrapper: (props) => (
      <TestContextProviders siteOptions={{ domain }} {...props} />
    )
  })

  await userEvent.click(screen.getByText('Gesamte Zeit'))
  expect(screen.getByTestId('datemenu')).toBeVisible()
  expect(screen.queryByText('Vergleichen')).toBeNull()
})

test.each([
  [{ period: 'all' }, 'Gesamte Zeit'],
  [{ period: 'month' }, 'Monat bis Heute'],
  [{ period: 'year' }, 'Jahr bis Heute']
])(
  'the dashboardState period from search %p is respected and stored',
  async (searchRecord, buttonText) => {
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`

    render(<DashboardPeriodPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          routerProps={{ initialEntries: [startUrl] }}
          {...props}
        />
      )
    })

    expect(screen.getByText(buttonText)).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(searchRecord.period)
  }
)

test.each([
  [
    { period: 'custom', from: '2024-08-10', to: '2024-08-20' },
    '10 Aug - 20 Aug 24'
  ],
  [{ period: 'realtime' }, 'Echtzeit']
])(
  'the dashboardState period from search %p is respected but not stored',
  async (searchRecord, buttonText) => {
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch(searchRecord)}`

    render(<DashboardPeriodPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain }}
          routerProps={{ initialEntries: [startUrl] }}
          {...props}
        />
      )
    })
    expect(screen.getByText(buttonText)).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(null)
  }
)

test.each([
  ['all', '7d', 'Letzte 7 Tage'],
  ['30d', 'month', 'Monat bis Heute']
])(
  'if the stored period is %p but dashboardState period is %p, dashboardState is respected and the stored period is overwritten',
  async (storedPeriod, dashboardPeriod, buttonText) => {
    localStorage.setItem(periodStorageKey, storedPeriod)
    const startUrl = `${getRouterBasepath({ domain, shared: false })}${stringifySearch({ period: dashboardPeriod })}`

    render(<DashboardPeriodPicker />, {
      wrapper: (props) => (
        <TestContextProviders
          siteOptions={{ domain, shared: false }}
          routerProps={{
            initialEntries: [startUrl]
          }}
          {...props}
        />
      )
    })

    await userEvent.click(screen.getByText(buttonText))
    expect(screen.getByTestId('datemenu')).toBeVisible()
    expect(localStorage.getItem(periodStorageKey)).toBe(dashboardPeriod)
  }
)

test('going back resets the stored dashboardState period to previous value', async () => {
  const BrowserBackButton = () => {
    const navigate = useNavigate()
    return (
      <button data-testid="browser-back" onClick={() => navigate(-1)}></button>
    )
  }
  render(
    <>
      <DashboardPeriodPicker />
      <BrowserBackButton />
    </>,
    {
      wrapper: (props) => (
        <TestContextProviders siteOptions={{ domain }} {...props} />
      )
    }
  )

  await userEvent.click(screen.getByText('Letzte 28 Tage'))
  await userEvent.click(screen.getByText('Jahr bis Heute'))
  expect(screen.queryByTestId('datemenu')).not.toBeInTheDocument()

  expect(localStorage.getItem(periodStorageKey)).toBe('year')

  await userEvent.click(screen.getByText('Jahr bis Heute'))
  await userEvent.click(screen.getByText('Monat bis Heute'))
  expect(screen.queryByTestId('datemenu')).not.toBeInTheDocument()

  expect(localStorage.getItem(periodStorageKey)).toBe('month')

  await userEvent.click(screen.getByTestId('browser-back'))
  expect(screen.getByText('Jahr bis Heute')).toBeVisible()
  expect(localStorage.getItem(periodStorageKey)).toBe('year')
})
