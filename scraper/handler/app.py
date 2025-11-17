import requests
from bs4 import BeautifulSoup
import re
from typing import List, Dict, Any
from urllib.parse import urlparse
import logging
from dataclasses import dataclass
import json
import boto3

apigw_management = boto3.client('apigatewaymanagementapi')

logger = logging.getLogger()
logger.setLevel(logging.INFO)

@dataclass
class ContentExtractionOptions:
    min_text_length: int = 100
    remove_selectors: List[str] = None
    preserve_line_breaks: bool = True
    timeout: int = 30
    headers: Dict[str, str] = None
    extract_metadata: bool = True
    max_content_length: int = None

class ContentExtractor:
    def __init__(self):
        self.default_remove_selectors = [
            'script', 'style', 'nav', 'header', 'footer',
            '.advertisement', '.ads', '.social-share', '.comments',
            '.related-posts', '[role="navigation"]', '[aria-hidden="true"]',
            '.sidebar', '.menu', '.popup', '.modal', 'iframe', 'form'
        ]
        
        self.content_selectors = [
            'article', 'main', '[role="main"]', '.content', '#content',
            '.post-content', '.article-content', '.entry-content',
            '.main-content', '.story-content', '.post-body',
            '.article-body', '.story-body'
        ]
        
        self.noise_patterns = [
            r'share on|follow us|subscribe|read more|advertisement',
            r'click here|learn more|sign up|download now',
            r'related articles|you may also like|recommended for you',
            r'\b\d{1,2}\s*(?:min|hour|day)\s*ago\b',
        ]

    def extract_content_from_url(self, url: str, options: ContentExtractionOptions = None) -> Dict[str, Any]:
        if options is None:
            options = ContentExtractionOptions()
            
        try:
            headers = options.headers or {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=options.timeout, verify=True)
            response.raise_for_status()

            content_type = response.headers.get('content-type', '')
            if 'text/html' not in content_type:
                raise ValueError(f"Unsupported content type: {content_type}")

            result = self.extract_relevant_text(response.text, url, options)
            
            if options.extract_metadata:
                result['metadata'] = self.extract_metadata(response.text, url)
                
            return result

        except Exception as e:
            logger.error(f"Error processing URL {url}: {e}")
            raise

    def extract_relevant_text(self, html: str, url: str = None, options: ContentExtractionOptions = None) -> Dict[str, Any]:
        if options is None:
            options = ContentExtractionOptions()

        soup = BeautifulSoup(html, 'html.parser')
        self.remove_unwanted_elements(soup, options.remove_selectors or [])
        
        content_element = self.find_content_element(soup, options.min_text_length)
        
        if not content_element:
            return {
                'content': '',
                'title': self.extract_title(soup),
                'url': url,
                'word_count': 0,
                'success': False
            }

        text = self.extract_clean_text(content_element, options.preserve_line_breaks)
        text = self.clean_extracted_text(text)
        
        if options.max_content_length and len(text) > options.max_content_length:
            text = text[:options.max_content_length] + '...'

        return {
            'content': text.strip(),
            'title': self.extract_title(soup),
            'url': url,
            'word_count': len(text.split()),
            'success': True
        }

    def remove_unwanted_elements(self, soup: BeautifulSoup, custom_selectors: List[str]):
        all_selectors = self.default_remove_selectors + custom_selectors
        for selector in all_selectors:
            try:
                for element in soup.select(selector):
                    element.decompose()
            except Exception as e:
                logger.warning(f"Error removing selector {selector}: {e}")

    def find_content_element(self, soup: BeautifulSoup, min_text_length: int):
        for selector in self.content_selectors:
            element = soup.select_one(selector)
            if element and self.is_content_sufficient(element, min_text_length):
                return element
        
        for element in [soup.find('body'), soup]:
            if element and self.is_content_sufficient(element, min_text_length):
                return element
        return None

    def is_content_sufficient(self, element, min_length: int) -> bool:
        text = element.get_text(strip=True)
        return len(text) >= min_length

    def extract_clean_text(self, element, preserve_line_breaks: bool) -> str:
        if preserve_line_breaks:
            for tag in element.find_all(['p', 'br', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li']):
                if tag.name == 'br':
                    tag.replace_with('\n')
                else:
                    if tag.get_text(strip=True):
                        tag.append('\n')
        
        text = element.get_text()
        text = re.sub(r'\s+', ' ', text)
        return text

    def clean_extracted_text(self, text: str) -> str:
        for pattern in self.noise_patterns:
            text = re.sub(pattern, '', text, flags=re.IGNORECASE)
        
        text = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '', text)
        text = re.sub(r'https?://\S+', '', text)
        
        lines = [line.strip() for line in text.split('\n') if line.strip()]
        text = '\n'.join(lines)
        text = re.sub(r'\n{3,}', '\n\n', text)
        
        return text

    def extract_title(self, soup: BeautifulSoup) -> str:
        title = soup.find('title')
        if title:
            return title.get_text(strip=True)
        
        h1 = soup.find('h1')
        if h1:
            return h1.get_text(strip=True)
        return ''

    def extract_metadata(self, html: str, url: str) -> Dict[str, Any]:
        soup = BeautifulSoup(html, 'html.parser')
        metadata = {
            'url': url,
            'domain': urlparse(url).netloc if url else '',
            'title': self.extract_title(soup),
            'description': '',
            'keywords': [],
            'language': soup.get('lang') or 'en'
        }
        
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc:
            metadata['description'] = meta_desc.get('content', '').strip()
        
        meta_keywords = soup.find('meta', attrs={'name': 'keywords'})
        if meta_keywords:
            keywords = meta_keywords.get('content', '').split(',')
            metadata['keywords'] = [kw.strip() for kw in keywords if kw.strip()]
        
        return metadata

def handler(event, context):
    connection_id = event['connectionId']
    url = event['url']

    logger.info(f"Received url: {url} connection_id: {connection_id}")
    
    try:
        if not url:
            send_message (connection_id, {
                'status': 'error',
                'message': 'URL parameter is required',
            })
        
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        extractor = ContentExtractor()
        options = ContentExtractionOptions(
            preserve_line_breaks=True,
            extract_metadata = False
        )
        
        result = extractor.extract_content_from_url(url, options)
        
        send_message (connection_id, {
            'status': 'complete',
            'results': {
                'title': result['title'],
                'content': result['content'],
                'word_count': result['word_count'],
                'success': result['success'],
                'url': result['url']
            }
        })
        
    except requests.RequestException as e:
        logger.error(f"Request error: {e}")
        send_message (connection_id, {
            'status': 'error',
            'message': f'Failed to fetch URL: {str(e)}',
        })
    
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        send_message (connection_id, {
            'status': 'error',
            'message': str(e),
        })

def send_message(connection_id, message):
    apigw_management.post_to_connection(
        ConnectionId=connection_id,
        Data=json.dumps(message).encode('utf-8')
    )