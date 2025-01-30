'use strict'

import * as path from 'node:path'

const SCRIPT_PATH = path.join(Deno.cwd(), 'script.js')
const STYLES_PATH = path.join(Deno.cwd(), 'styles.css')

Deno.serve((req: Request) => {
    const path = new URL(req.url).pathname
    switch(path) {
        case '/script.js':
            return serveStaticFile(SCRIPT_PATH, 'application/javascript')
        case '/styles.css':
            return serveStaticFile(STYLES_PATH, 'text/css')
        case '/': {
            const html = generateHtml({ testCases: findTestCases() })
            return new Response(html, { headers: { 'content-type': 'text/html' } })
        }
        default:
            return new Response('404 - Not Found', { status: 404 })
    }
})

function serveStaticFile(path: string, contentType: string): Response {
    try {
        const file = Deno.readFileSync(path)
        return new Response(file, { headers: { 'content-type': contentType } })
    } catch (err) {
        if (err instanceof Deno.errors.NotFound) {
            return new Response('404 - Not Found', { status: 404 })
        }
        throw err
    }
}

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
      <title>Test Cases</title>
      <link rel='stylesheet' href='/styles.css'>
      <script src='./script.js' defer></script>
    </head>
    <body>
      <table>
        <thead>
          <tr>
            <th>Ruby</th>
            <th>JavaScript</th>
          </tr>
        </thead>
        <tbody>
          ${testCases.map((tc) => `
              <tr>
                <td><pre class='code-block rb' title='${escapeHtml(tc.name)}'>${escapeHtml(tc.rb)}</pre></td>
                <td><pre class='code-block js' title='${escapeHtml(tc.name)}'>${escapeHtml(tc.js)}</pre></td>
              </tr>
            `).join('')}
        </tbody>
      </table>
    </body>
    </html>
  `
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