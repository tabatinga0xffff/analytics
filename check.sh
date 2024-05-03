echo $1

code_data() 
{
	cat <<EOF

export default async function ({ page }) {

await page.setUserAgent(
	"plausible.io Snippet Verification Agent - if abused contact support@plausible.io",
);

await page.goto("$1");
await page.waitForNetworkIdle({idleTime: 1000});
const url = await page.title();
const plausibleInstalled = await page.evaluate( () => typeof(window.plausible) === "function" );
return {
data: {
url, plausibleInstalled 
},
// Make sure to match the appropriate content here
type: "application/json",
};
}
EOF
}

curl -X POST http://0.0.0.0:3000/function?token=dummy_token -H "content-type: application/javascript" --data "$(code_data $1)"
