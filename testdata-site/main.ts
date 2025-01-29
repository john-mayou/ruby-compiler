'use strict';

import * as path from 'node:path';

Deno.serve((_req: Request) => new Response(
    generateHtml({ testCases: findTestCases() }),
    {
        headers: { 'content-type': 'text/html; charset=utf-8' }
    }
))

interface TestCase {
    name: string
    rb: string
    js: string
}

function findTestCases(): TestCase[] {
    const testCases: TestCase[] = []
    const rbDir = '../testdata/rb'
    const jsDir = '../testdata/js'

    const rbFiles = Deno.readDirSync('../testdata/rb')
    for (const rbFile of rbFiles) {
        const basename = path.basename(rbFile.name, '.rb')

        const rbPath = path.join(rbDir, rbFile.name)
        const rb = Deno.readTextFileSync(rbPath)

        const tryReadFileIfExists = (path: string) => {
            try {
                return Deno.readTextFileSync(path)
            } catch (err) {
                if (err instanceof Deno.errors.NotFound) {
                    return ''
                }
                throw err
            }
        }

        const jsPath = path.join(jsDir, `${basename}.js`)
        const js = tryReadFileIfExists(jsPath)

        testCases.push({ name: basename, rb, js })
    }

    return testCases
}

interface GenerateHtmlParams {
    testCases: TestCase[]
}

function generateHtml({ testCases }: GenerateHtmlParams): string {
  return `
    <!DOCTYPE html>
    <html lang='en'>
    <head>
      <title>Code Comparison</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f4f4f4; color: #333; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; border: 1px solid #ccc; vertical-align: top; }
        th { background: #eee; font-weight: bold; }
        pre { margin: 0; white-space: pre-wrap; word-wrap: break-word; font-family: Consolas, 'Courier New', monospace; }
        .code-block { background: #1e1e1e; color: #dcdcdc; padding: 10px; border-radius: 5px; }
      </style>
    </head>
    <body>
      <h1>Comparing Ruby and JS Code</h1>
      <table>
        <thead>
          <tr>
            <th>Ruby Code</th>
            <th>JS Code</th>
          </tr>
        </thead>
        <tbody>
          ${testCases.map((tc) => `
              <tr>
                <td><pre class='code-block'>${escapeHtml(tc.rb)}</pre></td>
                <td><pre class='code-block'>${escapeHtml(tc.js)}</pre></td>
              </tr>
            `).join('')}
        </tbody>
      </table>
    </body>
    </html>
  `;
}

function escapeHtml(unsafe: string): string {
    return (
        unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;")
    )
}