import { describe, test, expect } from 'bun:test';
import { renderTemplate } from '../templates/react-native/domain/CampaignUtils';

describe('renderTemplate', () => {
  test('replaces {{var}} with string value', () => {
    expect(renderTemplate('Hello {{name}}', { name: 'Alice' })).toBe('Hello Alice');
  });

  test('replaces multiple variables in one template', () => {
    expect(
      renderTemplate('{{greeting}} {{name}}!', { greeting: 'Hi', name: 'Bob' }),
    ).toBe('Hi Bob!');
  });

  test('unresolved {{unknown}} kept as-is', () => {
    expect(renderTemplate('Hello {{unknown}}', { name: 'Alice' })).toBe(
      'Hello {{unknown}}',
    );
  });

  test('dot-notation {{user.firstName}} resolves nested object', () => {
    expect(
      renderTemplate('Hi {{user.firstName}}', {
        user: { firstName: 'Carol' },
      }),
    ).toBe('Hi Carol');
  });

  test('null resolves to empty string', () => {
    expect(renderTemplate('Value: {{val}}', { val: null })).toBe('Value: ');
  });

  test('undefined resolves — placeholder kept as-is', () => {
    expect(renderTemplate('Value: {{val}}', { val: undefined })).toBe(
      'Value: {{val}}',
    );
  });

  test('number converts to string', () => {
    expect(renderTemplate('Count: {{n}}', { n: 42 })).toBe('Count: 42');
  });

  test('boolean true converts to "true", false to "false"', () => {
    expect(renderTemplate('{{a}} {{b}}', { a: true, b: false })).toBe(
      'true false',
    );
  });

  test('object converts to JSON.stringify', () => {
    const obj = { x: 1 };
    expect(renderTemplate('{{data}}', { data: obj })).toBe(JSON.stringify(obj));
  });

  test('deep dot-notation {{a.b.c}}', () => {
    expect(
      renderTemplate('{{a.b.c}}', { a: { b: { c: 'deep' } } }),
    ).toBe('deep');
  });

  test('no variables returns unchanged', () => {
    expect(renderTemplate('No vars here', {})).toBe('No vars here');
  });

  test('empty template returns empty string', () => {
    expect(renderTemplate('', { name: 'Alice' })).toBe('');
  });

  test('partial path {{user.missing.deep}} keeps placeholder', () => {
    expect(
      renderTemplate('{{user.missing.deep}}', { user: { name: 'Alice' } }),
    ).toBe('{{user.missing.deep}}');
  });
});
