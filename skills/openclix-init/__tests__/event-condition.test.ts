import { describe, test, expect } from 'bun:test';
import { EventConditionProcessor } from '../templates/react-native/domain/CampaignUtils';
import { makeEvent } from './helpers/fixtures';
import type { EventConditionGroup } from '../templates/react-native/domain/OpenClixTypes';

const processor = new EventConditionProcessor();

function process(group: EventConditionGroup, eventOverrides?: Parameters<typeof makeEvent>[0]) {
  return processor.process(group, makeEvent(eventOverrides));
}

describe('EventConditionProcessor', () => {
  describe('field resolution', () => {
    test('field=name matches event.name', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'equal', values: ['button_clicked'] }],
        }),
      ).toBe(true);
    });

    test('field=property matches event.properties[property_name]', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'color', operator: 'equal', values: ['red'] },
            ],
          },
          { properties: { color: 'red' } },
        ),
      ).toBe(true);
    });

    test('field=property with missing property yields null lhs', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'missing', operator: 'equal', values: ['x'] },
            ],
          },
          { properties: {} },
        ),
      ).toBe(false);
    });
  });

  describe('connector logic', () => {
    test('AND with all true', () => {
      expect(
        process({
          connector: 'and',
          conditions: [
            { field: 'name', operator: 'equal', values: ['button_clicked'] },
            { field: 'name', operator: 'starts_with', values: ['button'] },
          ],
        }),
      ).toBe(true);
    });

    test('AND with one false', () => {
      expect(
        process({
          connector: 'and',
          conditions: [
            { field: 'name', operator: 'equal', values: ['button_clicked'] },
            { field: 'name', operator: 'equal', values: ['wrong'] },
          ],
        }),
      ).toBe(false);
    });

    test('OR with one true', () => {
      expect(
        process({
          connector: 'or',
          conditions: [
            { field: 'name', operator: 'equal', values: ['wrong'] },
            { field: 'name', operator: 'equal', values: ['button_clicked'] },
          ],
        }),
      ).toBe(true);
    });

    test('OR with all false', () => {
      expect(
        process({
          connector: 'or',
          conditions: [
            { field: 'name', operator: 'equal', values: ['a'] },
            { field: 'name', operator: 'equal', values: ['b'] },
          ],
        }),
      ).toBe(false);
    });

    test('AND with empty conditions returns true', () => {
      expect(process({ connector: 'and', conditions: [] })).toBe(true);
    });

    test('OR with empty conditions returns false', () => {
      expect(process({ connector: 'or', conditions: [] })).toBe(false);
    });
  });

  describe('operators', () => {
    test('equal — exact string match', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'equal', values: ['button_clicked'] }],
        }),
      ).toBe(true);
    });

    test('not_equal — different string', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'not_equal', values: ['other'] }],
        }),
      ).toBe(true);
    });

    test('greater_than — numeric comparison', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'count', operator: 'greater_than', values: ['5'] },
            ],
          },
          { properties: { count: 10 } },
        ),
      ).toBe(true);
    });

    test('greater_than_or_equal — boundary', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'count', operator: 'greater_than_or_equal', values: ['10'] },
            ],
          },
          { properties: { count: 10 } },
        ),
      ).toBe(true);
    });

    test('less_than — numeric comparison', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'count', operator: 'less_than', values: ['20'] },
            ],
          },
          { properties: { count: 10 } },
        ),
      ).toBe(true);
    });

    test('less_than_or_equal — boundary', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'count', operator: 'less_than_or_equal', values: ['10'] },
            ],
          },
          { properties: { count: 10 } },
        ),
      ).toBe(true);
    });

    test('contains — substring', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'contains', values: ['button'] }],
        }),
      ).toBe(true);
    });

    test('not_contains — missing substring', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'not_contains', values: ['xyz'] }],
        }),
      ).toBe(true);
    });

    test('starts_with — prefix', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'starts_with', values: ['button'] }],
        }),
      ).toBe(true);
    });

    test('ends_with — suffix', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'ends_with', values: ['clicked'] }],
        }),
      ).toBe(true);
    });

    test('matches — valid regex', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'matches', values: ['^button_.*$'] }],
        }),
      ).toBe(true);
    });

    test('matches — invalid regex returns false', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'matches', values: ['[invalid'] }],
        }),
      ).toBe(false);
    });

    test('exists — property present', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'color', operator: 'exists', values: [] },
            ],
          },
          { properties: { color: 'red' } },
        ),
      ).toBe(true);
    });

    test('exists — property missing', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'missing', operator: 'exists', values: [] },
            ],
          },
          { properties: {} },
        ),
      ).toBe(false);
    });

    test('not_exists — property missing', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'missing', operator: 'not_exists', values: [] },
            ],
          },
          { properties: {} },
        ),
      ).toBe(true);
    });

    test('not_exists — property present', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'color', operator: 'not_exists', values: [] },
            ],
          },
          { properties: { color: 'red' } },
        ),
      ).toBe(false);
    });

    test('in — lhs in values array', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'in', values: ['button_clicked', 'other'] }],
        }),
      ).toBe(true);
    });

    test('not_in — lhs not in values', () => {
      expect(
        process({
          connector: 'and',
          conditions: [{ field: 'name', operator: 'not_in', values: ['a', 'b'] }],
        }),
      ).toBe(true);
    });

    test('non-numeric comparison returns false (NaN)', () => {
      expect(
        process(
          {
            connector: 'and',
            conditions: [
              { field: 'property', property_name: 'val', operator: 'greater_than', values: ['5'] },
            ],
          },
          { properties: { val: 'not_a_number' } },
        ),
      ).toBe(false);
    });
  });

  describe('null/undefined lhs', () => {
    test('null lhs: not_equal, not_contains, not_in, not_exists return true', () => {
      for (const operator of ['not_equal', 'not_contains', 'not_in', 'not_exists'] as const) {
        expect(
          process(
            {
              connector: 'and',
              conditions: [
                { field: 'property', property_name: 'missing', operator, values: ['x'] },
              ],
            },
            { properties: {} },
          ),
        ).toBe(true);
      }
    });

    test('null lhs: exists, equal, contains, greater_than return false', () => {
      for (const operator of ['exists', 'equal', 'contains', 'greater_than'] as const) {
        expect(
          process(
            {
              connector: 'and',
              conditions: [
                { field: 'property', property_name: 'missing', operator, values: ['x'] },
              ],
            },
            { properties: {} },
          ),
        ).toBe(false);
      }
    });
  });

  describe('edge cases', () => {
    test('unknown field value returns false', () => {
      expect(
        process({
          connector: 'and',
          conditions: [
            { field: 'unknown_field' as any, operator: 'equal', values: ['x'] },
          ],
        }),
      ).toBe(false);
    });

    test('unknown operator value returns false', () => {
      expect(
        process({
          connector: 'and',
          conditions: [
            { field: 'name', operator: 'unknown_op' as any, values: ['x'] },
          ],
        }),
      ).toBe(false);
    });
  });
});
