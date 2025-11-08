import streamlit as st
import requests
import os

st.set_page_config(
    page_title="Codebase Genius",
    page_icon="🤖",
    layout="wide"
)

st.title("🤖 Codebase Genius – AI Repo Documentation Generator")

st.markdown("""
Turn any GitHub repository into a **beautiful AI-generated documentation** powered by Jaseci + Gemini.
""")

#  Input Section 
st.sidebar.header(" Repository Input")
repo_url = st.sidebar.text_input(
    "Enter GitHub repository URL",
    placeholder="https://github.com/psf/requests"
)
generate = st.sidebar.button("Generate Documentation")

st.sidebar.markdown("---")
st.sidebar.info("Backend ready? The generator connects to your Jac API to process repositories.")

# Main UI 
if generate and repo_url.strip():
    with st.spinner("🧠 Cloning and analyzing repository... "):
        payload = {"utterance": repo_url.strip(), "session_id": ""}
        try:
            res = requests.post(
                "http://localhost:8000/walker/codegenius",
                json=payload,
                timeout=120
            )

            if res.status_code == 200:
                report = res.json()["reports"][0]
                summary = report.get("summary", "")
                doc_path = report.get("doc_path", "")
                repo_path = report.get("repo_path", "")

                st.success(" Documentation generated successfully!")

                st.subheader(" Summary")
                st.markdown(f"```\n{summary}\n```")
                if "markdown" in report:
                    st.subheader(" Download Generated Documentation")
                    st.download_button(
                        label="⬇Download Documentation (Markdown)",
                        data=report["markdown"],
                        file_name="docs.md",
                        mime="text/markdown"
                    )

                abs_doc_path = os.path.join(
                    os.path.expanduser("~/Documents/codebase_genius"), doc_path
                )

            else:
                st.error(f"Backend returned error {res.status_code}: {res.text}")

        except requests.exceptions.RequestException as e:
            st.error(f" Failed to connect to Jac backend: {e}")
else:
    st.info("👈 Enter a GitHub repo on the left and click **Generate Documentation**.")

# Footer
st.markdown("---")
st.caption("Made with using Streamlit, JacLang, and Gemini-2.0")
